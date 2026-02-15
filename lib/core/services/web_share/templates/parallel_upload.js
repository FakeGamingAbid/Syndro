/**
 * Syndro Parallel Upload for Browser
 * 
 * Uploads file chunks in parallel from browser to app
 * Supports encryption (AES-256-GCM)
 */

class SyndroParallelUploader {
  constructor(options = {}) {
    this.connections = options.connections || 2;
    this.chunkSize = options.chunkSize || 1024 * 1024; // 1MB
    this.baseUrl = options.baseUrl || window.location.origin;
    this.encryptionKey = null;
    this.onProgress = options.onProgress || (() => {});
    this.onComplete = options.onComplete || (() => {});
    this.onError = options.onError || console.error;
  }

  /**
   * Initialize encryption from URL fragment or generate new key
   */
  async initEncryption(keyBase64 = null) {
    try {
      if (keyBase64) {
        // Use provided key
        const keyBytes = this._base64UrlToBytes(keyBase64);
        this.encryptionKey = await crypto.subtle.importKey(
          'raw',
          keyBytes,
          { name: 'AES-GCM' },
          true,
          ['encrypt']
        );
      } else {
        // Generate new key
        this.encryptionKey = await crypto.subtle.generateKey(
          { name: 'AES-GCM', length: 256 },
          true,
          ['encrypt']
        );
      }
      
      console.log('🔐 Encryption initialized');
      return true;
    } catch (e) {
      console.error('Failed to initialize encryption:', e);
      return false;
    }
  }

  /**
   * Get encryption key as base64url for sharing
   */
  async getKeyBase64() {
    if (!this.encryptionKey) return null;
    
    const keyBytes = await crypto.subtle.exportKey('raw', this.encryptionKey);
    return this._bytesToBase64Url(new Uint8Array(keyBytes));
  }

  /**
   * Upload file with parallel chunks
   */
  async uploadFile(file, options = {}) {
    const { transferId, encrypted = false } = options;
    const fileName = file.name;
    const fileSize = file.size;
    const totalChunks = Math.ceil(fileSize / this.chunkSize);
    
    console.log(`📤 Starting parallel upload: ${fileName}`);
    console.log(`   Size: ${this._formatBytes(fileSize)}, Chunks: ${totalChunks}`);
    
    // Initialize encryption if needed
    if (encrypted) {
      await this.initEncryption();
    }
    
    // Calculate file hash
    console.log('📝 Calculating file hash...');
    const fileHash = await this._calculateFileHash(file);
    console.log(`   Hash: ${fileHash.substring(0, 16)}...`);
    
    // Initiate transfer
    const initResponse = await fetch(`${this.baseUrl}/transfer/parallel/initiate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        transferId,
        fileName,
        fileSize,
        fileHash,
        totalChunks,
        chunkSize: this.chunkSize,
        encrypted,
      }),
    });
    
    if (!initResponse.ok) {
      throw new Error('Failed to initiate transfer');
    }
    
    // Create chunk info
    const chunks = [];
    for (let i = 0; i < totalChunks; i++) {
      const start = i * this.chunkSize;
      const end = Math.min(start + this.chunkSize, fileSize);
      chunks.push({ index: i, start, end, size: end - start });
    }
    
    // Upload tracking
    let completedChunks = 0;
    let bytesUploaded = 0;
    
    // Upload chunk function
    const uploadChunk = async (chunk) => {
      // Read chunk from file
      const blob = file.slice(chunk.start, chunk.end);
      let data = new Uint8Array(await blob.arrayBuffer());
      
      // Encrypt if needed
      if (encrypted && this.encryptionKey) {
        data = await this._encryptChunk(data);
      }
      
      // Upload
      const response = await fetch(`${this.baseUrl}/transfer/chunk`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/octet-stream',
          'X-Transfer-Id': transferId,
          'X-Chunk-Index': chunk.index.toString(),
          'X-Original-Size': chunk.size.toString(),
          'X-Encrypted': encrypted.toString(),
        },
        body: data,
      });
      
      if (!response.ok) {
        throw new Error(`Chunk ${chunk.index} upload failed`);
      }
      
      completedChunks++;
      bytesUploaded += chunk.size;
      
      this.onProgress({
        chunksCompleted: completedChunks,
        totalChunks,
        bytesUploaded,
        totalBytes: fileSize,
        percentage: (completedChunks / totalChunks) * 100,
      });
    };
    
    // Process with parallelism
    const queue = [...chunks];
    const workers = [];
    
    for (let i = 0; i < this.connections; i++) {
      workers.push(this._processQueue(queue, uploadChunk));
    }
    
    await Promise.all(workers);
    
    // Notify completion
    const completeResponse = await fetch(`${this.baseUrl}/transfer/parallel/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transferId, fileHash }),
    });
    
    const result = await completeResponse.json();
    
    if (result.success) {
      console.log(`✅ Upload complete: ${fileName}`);
      this.onComplete({ fileName, fileSize, success: true });
    } else {
      throw new Error(result.error || 'Upload verification failed');
    }
    
    return result;
  }

  /**
   * Process upload queue
   */
  async _processQueue(queue, processor) {
    while (queue.length > 0) {
      const chunk = queue.shift();
      if (chunk) {
        await processor(chunk);
      }
    }
  }

  /**
   * Calculate SHA-256 hash of file
   */
  async _calculateFileHash(file) {
    const buffer = await file.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }

  /**
   * Encrypt chunk using AES-256-GCM
   */
  async _encryptChunk(data) {
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    
    const encrypted = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: nonce, tagLength: 128 },
      this.encryptionKey,
      data
    );
    
    // Combine: nonce (12) + ciphertext + tag (16)
    const result = new Uint8Array(12 + encrypted.byteLength);
    result.set(nonce, 0);
    result.set(new Uint8Array(encrypted), 12);
    
    return result;
  }

  /**
   * Base64URL to Uint8Array
   */
  _base64UrlToBytes(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
    const padding = '='.repeat((4 - base64.length % 4) % 4);
    const binary = atob(base64 + padding);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  /**
   * Uint8Array to Base64URL
   */
  _bytesToBase64Url(bytes) {
    const binary = String.fromCharCode(...bytes);
    const base64 = btoa(binary);
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  /**
   * Format bytes
   */
  _formatBytes(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
}

// Export
window.SyndroParallelUploader = SyndroParallelUploader;
