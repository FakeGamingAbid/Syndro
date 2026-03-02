/// Localization constants for transfer request sheet
/// Uses AppLocalizations for multi-language support
class TransferRequestStrings {
  /// Get incoming transfer string
  static String incomingTransfer(dynamic l10n) => l10n.incomingTransfer;
  
  /// Get sender wants to send message
  static String senderWantsToSend(dynamic l10n) => 'wants to send you:';
  
  /// Get file count string
  static String fileCount(int count, dynamic l10n) => count == 1 
      ? '1 ${l10n.fileCountWithSize(1, '').replaceAll('1 ', '').replaceAll(RegExp(r' • .*'), '')}'
      : '$count ${l10n.fileCountWithSize(count, '').replaceAll(RegExp(r'\d+ '), '').replaceAll(RegExp(r' • .*'), '')}';
  
  /// Get decline button text
  static String decline(dynamic l10n) => l10n.reject;
  
  /// Get accept button text
  static String accept(dynamic l10n) => l10n.accept;
  
  /// Get accept and trust button text
  static String acceptAndTrust(dynamic l10n) => '${l10n.accept} & ${l10n.autoAcceptTrusted}';
  
  /// Get transfer approved message
  static String transferApproved(dynamic l10n) => l10n.transferAccepted;
  
  /// Get transfer rejected message
  static String transferRejected(dynamic l10n) => l10n.transferRejected;
}
