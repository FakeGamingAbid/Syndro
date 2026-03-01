/// FIX V18: Localization constants for transfer request sheet
class TransferRequestStrings {
  // Sheet title and messages
  static const String incomingTransfer = 'Incoming Transfer';
  static const String senderWantsToSend = 'wants to send you:';
  
  // File info
  static String fileCount(int count) => count == 1 ? '1 file' : '$count files';
  
  // Button labels
  static const String decline = 'Decline';
  static const String accept = 'Accept';
  static const String acceptAndTrust = 'Accept & Always Trust This Device';
  
  // Confirmation messages
  static const String transferApproved = 'Transfer accepted';
  static const String transferRejected = 'Transfer rejected';
}
