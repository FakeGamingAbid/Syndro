/**
 * Syndro Parallel Download for Browser
 * 
 * Downloads file chunks in parallel and assembles them
 * Supports encryption (AES-256-GCM)
 */

class SyndroParallelDownloader {
  constructor(options = {}) {
    this.connections = options.connections || 2;
    this.baseUrl = options.baseUrl || window.location.origin;
    this.encryptionKey = null;
    this.onProgress = options.onProgress || (() => {});
    this.onComplete = options.onComplete || (() => {});
    this.onError = options.onError || console.error;
  }

  /**
   * Initialize encryption from URL fragment
   * URL format: ...#key=BASE64_KEY
   */
  async initEncryption() {
    const hash = window.location.hash;
    if (!hash || !hash.includes('key=')) {
      console.log('No encryption key in URL, downloading unencrypted');
      return false;
    }

    try {
      const keyBase64 = hash.split('key=')[1].split('&')[0];
      const keyBytes = this._base64UrlToBytes(keyBase64);
      
      this.encryptionKey = await crypto.subtle.importKey(
        'raw',
        keyBytes,
        { name: 'AES-GCM' },
        false,
        ['decrypt']
      );
      
      console.log('🔐 Encryption key loaded');
      return true;
    } catch (e) {
      console.error('Failed to load encryption key:', e);
      return false;
    }
  }

  /**
   * Download file with parallel chunks
   */
  async downloadFile(fileInfo) {
    const { transferId, fileName, fileSize, totalChunks, chunkSize, encrypted } = fileInfo;
    
    console.log(`📥 Starting parallel download: ${fileName}`);
    console.log(`   Size: ${this._formatBytes(fileSize)}, Chunks: ${totalChunks}`);
    
    // Initialize encryption if needed
    if (encrypted) {
      await this.initEncryption();
      if (!this.encryptionKey) {
        throw new Error('Encryption required but key not available');
      }
    }
    
    // Create chunk queues for each connection
    const chunks = [];
    for (let i = 0; i < totalChunks; i++) {
      chunks.push({
        index: i,
        start: i * chunkSize,
        end: Math.min((i + 1) * chunkSize, fileSize),
        size: Math.min(chunkSize, fileSize - i * chunkSize),
      });
    }
    
    // Download chunks in parallel
    const downloadedChunks = new Array(totalChunks).fill(null);
    let completedChunks = 0;
    let bytesDownloaded = 0;
    
    // Create worker function
    const downloadChunk = async (chunk) => {
      const response = await fetch(
        `${this.baseUrl}/transfer/chunk/${transferId}/${chunk.index}`,
        { method: 'GET' }
      );
      
      if (!response.ok) {
        throw new Error(`Chunk ${chunk.index} download failed: ${response.status}`);
      }
      
      let data = new Uint8Array(await response.arrayBuffer());
      
      // Decrypt if needed
      if (encrypted && this.encryptionKey) {
        data = await this._decryptChunk(data);
      }
      
      downloadedChunks[chunk.index] = data;
      completedChunks++;
      bytesDownloaded += data.length;
      
      this.onProgress({
        chunksCompleted: completedChunks,
        totalChunks,
        bytesDownloaded,
        totalBytes: fileSize,
        percentage: (completedChunks / totalChunks) * 100,
      });
    };
    
    // Process chunks with limited parallelism
    const queue = [...chunks];
    const workers = [];
    
    for (let i = 0; i < this.connections; i++) {
      workers.push(this._processQueue(queue, downloadChunk));
    }
    
    await Promise.all(workers);
    
    // Verify all chunks received
    const missing = downloadedChunks.findIndex(c => c === null);
    if (missing !== -1) {
      throw new Error(`Missing chunk: ${missing}`);
    }
    
    // Assemble file
    console.log('📦 Assembling file...');
    const assembledData = this._assembleChunks(downloadedChunks);
    
    // Create download
    const blob = new Blob([assembledData]);
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    console.log(`✅ Download complete: ${fileName}`);
    this.onComplete({ fileName, fileSize, success: true });
    
    return { success: true, fileName, fileSize };
  }

  /**
   * Process download queue
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
   * Assemble chunks into single Uint8Array
   */
  _assembleChunks(chunks) {
    const totalSize = chunks.reduce((sum, c) => sum + c.length, 0);
    const result = new Uint8Array(totalSize);
    let offset = 0;
    
    for (const chunk of chunks) {
      result.set(chunk, offset);
      offset += chunk.length;
    }
    
    return result;
  }

  /**
   * Decrypt chunk using AES-256-GCM
   */
  async _decryptChunk(encryptedData) {
    if (encryptedData.length < 28) {
      throw new Error('Data too small to decrypt');
    }
    
    const nonce = encryptedData.slice(0, 12);
    const ciphertextWithTag = encryptedData.slice(12);
    
    const decrypted = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: nonce, tagLength: 128 },
      this.encryptionKey,
      ciphertextWithTag
    );
    
    return new Uint8Array(decrypted);
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
   * Format bytes to human readable
   */
  _formatBytes(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
}

// Export for use
window.SyndroParallelDownloader = SyndroParallelDownloader;
