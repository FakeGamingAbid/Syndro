/// Application-wide configuration constants
/// 
/// This class centralizes all configuration values to ensure consistency
/// and make it easy to modify settings in one place.
/// 
/// ## Usage
/// 
/// ```dart
/// if (fileSize > AppConfig.maxFileSizeBytes) {
///   throw Exception('File too large');
/// }
/// ```
class AppConfig {
  AppConfig._();

  // ============================================
  // TRANSFER CONFIGURATION
  // ============================================

  /// Maximum file size supported (100GB)
  /// 
  /// This limit exists to ensure compatibility with low-end devices.
  /// Files are streamed, so only one chunk is loaded in memory at a time.
  static const int maxFileSizeBytes = 100 * 1024 * 1024 * 1024;

  /// Maximum number of retries for failed transfers
  static const int maxTransferRetries = 3;

  /// Initial delay between retries (exponential backoff)
  static const int initialRetryDelaySeconds = 2;

  /// Maximum number of completed transfers to keep in history
  static const int maxCompletedTransfers = 10;

  /// Default chunk size for streaming transfers (1MB)
  static const int defaultChunkSize = 1024 * 1024;

  // ============================================
  // ENCRYPTION CONFIGURATION
  // ============================================

  /// Maximum nonces per encryption key before requiring rotation
  /// 
  /// Set to 2^32 for safety margin (well below GCM's 2^96 limit)
  static const int maxNoncesPerKey = 0xFFFFFFFF;

  /// Maximum cached nonces for collision detection
  /// 
  /// This bounds memory usage while still providing good collision protection
  static const int maxCachedNonces = 10000;

  /// Maximum chunk size for encryption (100MB)
  static const int maxEncryptionChunkSize = 100 * 1024 * 1024;

  // ============================================
  // NETWORK CONFIGURATION
  // ============================================

  /// Default transfer server port
  static const int defaultTransferPort = 8765;

  /// UDP broadcast port for device discovery
  static const int udpDiscoveryPort = 8771;

  /// Default web share port
  static const int defaultWebSharePort = 8766;

  /// List of ports to scan for device discovery
  static const List<int> discoveryPorts = [
    8765, 8766, 8767, 8768, 8769, 8770,
    50500, 50050,
  ];

  /// Device discovery timeout in seconds
  static const int discoveryTimeoutSeconds = 30;

  /// Maximum connected clients for web sharing
  static const int maxConnectedClients = 500;

  /// Web share expiration time in hours
  static const int webShareExpirationHours = 1;

  // ============================================
  // SESSION CONFIGURATION
  // ============================================

  /// Maximum age of an encryption session before requiring re-keying
  static const Duration sessionMaxAge = Duration(hours: 1);

  // ============================================
  // FILE SERVICE CONFIGURATION
  // ============================================

  /// Maximum filename length (200 characters)
  static const int maxFilenameLength = 200;

  /// Maximum file size for direct (non-streaming) read (10MB)
  static const int maxDirectReadSize = 10 * 1024 * 1024;

  // ============================================
  // RATE LIMITING CONFIGURATION
  // ============================================

  /// Maximum discovery operations per minute
  static const int maxDiscoveryRatePerMinute = 10;

  /// Rate limiting window in seconds
  static const int rateLimitWindowSeconds = 60;
}

/// Network-related configuration constants
class NetworkConfig {
  NetworkConfig._();

  /// HTTP timeout for connection establishment
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// HTTP timeout for receiving data
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// HTTP timeout for sending data
  static const Duration sendTimeout = Duration(seconds: 60);

  /// Maximum concurrent connections for parallel transfers
  static const int maxParallelConnections = 6;
}

/// UI-related configuration constants
class UIConfig {
  UIConfig._();

  /// Default window width for desktop
  static const double defaultWindowWidth = 1200.0;

  /// Default window height for desktop
  static const double defaultWindowHeight = 800.0;

  /// Minimum window width for desktop
  static const double minWindowWidth = 400.0;

  /// Minimum window height for desktop
  static const double minWindowHeight = 600.0;

  /// Animation duration for standard transitions
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);

  /// Animation duration for quick transitions
  static const Duration quickAnimationDuration = Duration(milliseconds: 150);
}
