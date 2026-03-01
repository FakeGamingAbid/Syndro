/// FIX V17: Localization constants for home screen
class HomeScreenStrings {
  // Screen titles
  static const String devices = 'Devices';
  static const String history = 'History';
  
  // Loading states
  static const String initializing = 'Initializing...';
  static const String scanningForDevices = 'Scanning for devices...';
  
  // Empty state
  static const String noDevicesFound = 'No devices found';
  static const String noDevicesTip = 
      'Make sure other devices have Syndro open and are on the same WiFi network';
  static const String scanAgain = 'Scan Again';
  
  // Error states
  static const String errorDiscoveringDevices = 'Error discovering devices';
  static const String retry = 'Retry';
  
  // Share options
  static const String shareViaWeb = 'Share via Web';
  static const String receiveViaWeb = 'Receive via Web';
  
  // Snackbar messages
  static const String transferAccepted = 'Transfer accepted';
  static const String transferRejected = 'Transfer rejected';
  static String failedToAccept(String error) => 'Failed to accept: $error';
  static String failedToReject(String error) => 'Failed to reject: $error';
  
  // Transfer request sheet
  static const String incomingTransfer = 'Incoming Transfer';
  static String fromDevice(String deviceName) => 'From: $deviceName';
  static String fileCountWithSize(int count, String size) => '$count file(s) • $size';
  static const String reject = 'REJECT';
  static const String accept = 'ACCEPT';
}
