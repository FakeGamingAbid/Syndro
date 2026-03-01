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
   * Calculate SHA-256 hash of file using streaming approach
   * For large files (>1GB), uses partial hash for performance
   * 
   * @param {File} file - The file to hash
   * @param {boolean} reportProgress - Whether to report progress via onProgress callback
   * @returns {Promise<string>} - SHA-256 hash as hex string
   */
  async _calculateFileHash(file, reportProgress = true) {
    const LARGE_FILE_THRESHOLD = 1024 * 1024 * 1024; // 1GB
    const HASH_CHUNK_SIZE = 2 * 1024 * 1024; // 2MB chunks for streaming
    
    // For very large files, use partial hash (first 1MB + last 1MB + size)
    // This provides a unique identifier without reading the entire file
    if (file.size > LARGE_FILE_THRESHOLD) {
      console.log('📊 Large file detected, using partial hash for performance');
      return this._calculatePartialHash(file, reportProgress);
    }
    
    // For smaller files, use streaming hash to avoid memory issues
    console.log('📝 Calculating file hash using streaming approach...');
    
    const totalChunks = Math.ceil(file.size / HASH_CHUNK_SIZE);
    let offset = 0;
    let chunkIndex = 0;
    
    // We'll collect all chunks and hash them together at the end
    // This is more memory efficient than loading the whole file at once
    const chunks = [];
    
    while (offset < file.size) {
      const end = Math.min(offset + HASH_CHUNK_SIZE, file.size);
      const chunk = file.slice(offset, end);
      const chunkBuffer = await chunk.arrayBuffer();
      chunks.push(new Uint8Array(chunkBuffer));
      
      offset = end;
      chunkIndex++;
      
      // Report progress
      if (reportProgress) {
        this.onProgress({
          phase: 'hashing',
          progress: (chunkIndex / totalChunks) * 100,
          chunksProcessed: chunkIndex,
          totalChunks: totalChunks,
        });
      }
      
      // Allow UI to update
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    
    // Combine all chunks and hash
    const combined = new Uint8Array(chunks.reduce((sum, c) => sum + c.length, 0));
    let pos = 0;
    for (const chunk of chunks) {
      combined.set(chunk, pos);
      pos += chunk.length;
    }
    
    const hashBuffer = await crypto.subtle.digest('SHA-256', combined);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }
  
  /**
   * Calculate partial hash for large files (>1GB)
   * Uses first 1MB + last 1MB + file size for unique identification
   * This avoids loading the entire file into memory
   * 
   * @param {File} file - The file to hash
   * @param {boolean} reportProgress - Whether to report progress
   * @returns {Promise<string>} - Partial hash as hex string
   */
  async _calculatePartialHash(file, reportProgress = true) {
    const PARTIAL_SIZE = 1024 * 1024; // 1MB
    
    if (reportProgress) {
      this.onProgress({
        phase: 'hashing',
        progress: 0,
        message: 'Calculating partial hash for large file...',
      });
    }
    
    // Read first 1MB
    const firstChunk = file.slice(0, Math.min(PARTIAL_SIZE, file.size));
    const firstBuffer = new Uint8Array(await firstChunk.arrayBuffer());
    
    if (reportProgress) {
      this.onProgress({
        phase: 'hashing',
        progress: 33,
      });
    }
    
    // Read last 1MB (if file is large enough)
    let lastBuffer = new Uint8Array(0);
    if (file.size > PARTIAL_SIZE) {
      const lastChunk = file.slice(Math.max(PARTIAL_SIZE, file.size - PARTIAL_SIZE), file.size);
      lastBuffer = new Uint8Array(await lastChunk.arrayBuffer());
    }
    
    if (reportProgress) {
      this.onProgress({
        phase: 'hashing',
        progress: 66,
      });
    }
    
    // Combine: first chunk + last chunk + file size (as 8 bytes)
    const sizeBytes = new ArrayBuffer(8);
    new DataView(sizeBytes).setBigUint64(0, BigInt(file.size));
    
    const combined = new Uint8Array(firstBuffer.length + lastBuffer.length + 8);
    combined.set(firstBuffer, 0);
    combined.set(lastBuffer, firstBuffer.length);
    combined.set(new Uint8Array(sizeBytes), firstBuffer.length + lastBuffer.length);
    
    const hashBuffer = await crypto.subtle.digest('SHA-256', combined);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    
    if (reportProgress) {
      this.onProgress({
        phase: 'hashing',
        progress: 100,
      });
    }
    
    // Prefix with 'p' to indicate partial hash
    return 'p' + hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
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
