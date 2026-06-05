/**
 * Syndro Browser Decryption
 * 
 * Uses Web Crypto API (hardware accelerated)
 * Speed: ~400-600 MB/s in modern browsers
 */

class SyndroDecryptor {
  constructor() {
    this.secretKey = null;
  }

  /**
   * Initialize with key from URL
   * Key is passed as base64url in URL fragment: #key=xxxx
   */
  async initFromUrl() {
    const hash = window.location.hash;
    if (!hash || !hash.includes('key=')) {
      throw new Error('No encryption key in URL');
    }

    const keyBase64 = hash.split('key=')[1].split('&')[0];
    const keyBytes = this.base64UrlToBytes(keyBase64);
    
    this.secretKey = await crypto.subtle.importKey(
      'raw',
      keyBytes,
      { name: 'AES-GCM' },
      false,
      ['decrypt']
    );

    console.log('🔐 Decryption key loaded');
  }

  /**
   * Decrypt a chunk of data
   * Input format: [nonce (12 bytes) | ciphertext | mac (16 bytes)]
   */
  async decryptChunk(encryptedData) {
    if (!this.secretKey) {
      throw new Error('Decryptor not initialized');
    }

    const data = new Uint8Array(encryptedData);
    
    if (data.length < 28) {
      throw new Error(`Data too small: ${data.length} bytes`);
    }

    // Extract components
    const nonce = data.slice(0, 12);
    const ciphertextWithTag = data.slice(12);

    try {
      const decrypted = await crypto.subtle.decrypt(
        { 
          name: 'AES-GCM', 
          iv: nonce,
          tagLength: 128  // 16 bytes = 128 bits
        },
        this.secretKey,
        ciphertextWithTag
      );

      return new Uint8Array(decrypted);

    } catch (e) {
      throw new Error('Decryption failed: Invalid key or corrupted data');
    }
  }

  /**
   * Decrypt streaming download
   */
  async decryptStream(response, onProgress) {
    const reader = response.body.getReader();
    const chunks = [];
    let buffer = new Uint8Array(0);
    let totalDecrypted = 0;

    while (true) {
      const { done, value } = await reader.read();
      
      if (done) break;

      // Append to buffer
      const newBuffer = new Uint8Array(buffer.length + value.length);
      newBuffer.set(buffer);
      newBuffer.set(value, buffer.length);
      buffer = newBuffer;

      // Process complete chunks
      while (buffer.length >= 4) {
        // Read chunk size (4 bytes, big endian)
        const size = (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];

        if (buffer.length < 4 + size) {
          break;  // Wait for more data
        }

        // Extract and decrypt chunk
        const encryptedChunk = buffer.slice(4, 4 + size);
        buffer = buffer.slice(4 + size);

        const decrypted = await this.decryptChunk(encryptedChunk);
        chunks.push(decrypted);
        totalDecrypted += decrypted.length;

        if (onProgress) {
          onProgress(totalDecrypted);
        }
      }
    }

    // Combine all decrypted chunks
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
      result.set(chunk, offset);
      offset += chunk.length;
    }

    return result;
  }

  /**
   * Download and decrypt file
   */
  async downloadAndDecrypt(url, fileName, onProgress) {
    console.log('🔐 Starting encrypted download:', fileName);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Download failed: ${response.status}`);
    }

    const decrypted = await this.decryptStream(response, onProgress);

    // Create download
    const blob = new Blob([decrypted]);
    const downloadUrl = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = downloadUrl;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    
    URL.revokeObjectURL(downloadUrl);

    console.log('🔐 Download complete:', fileName);
    return decrypted.length;
  }

  // Utility: Base64URL to Uint8Array
  base64UrlToBytes(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
    const padding = '='.repeat((4 - base64.length % 4) % 4);
    const binary = atob(base64 + padding);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }
}

// Global instance
const syndroDecryptor = new SyndroDecryptor();

// Initialize on page load
document.addEventListener('DOMContentLoaded', async () => {
  try {
    await syndroDecryptor.initFromUrl();
    document.getElementById('status').textContent = '🔐 Ready to download';
  } catch (e) {
    document.getElementById('status').textContent = '❌ ' + e.message;
  }
});
