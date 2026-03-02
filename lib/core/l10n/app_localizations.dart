import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

/// Extension to easily get localizations in any widget
extension AppLocalizationsExtension on BuildContext {
  /// Get the current locale
  Locale? get locale => ref.watch(localeProvider).locale;
  
  /// Check if locale is loaded
  bool get isLocaleLoaded => !ref.watch(localeProvider).isLoading;
}

/// Helper class to get localized strings
/// Usage: AppLocalizations.of(context).devices
class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  // Placeholder methods - these will be generated from ARB files
  // For now, we use a fallback approach
  
  String get devices => _t('Devices');
  String get history => _t('History');
  String get settings => _t('Settings');
  String get initializing => _t('Initializing...');
  String get scanningForDevices => _t('Scanning for devices...');
  String get noDevicesFound => _t('No devices found');
  String get scanAgain => _t('Scan Again');
  String get retry => _t('Retry');
  String get shareViaWeb => _t('Share via Web');
  String get receiveViaWeb => _t('Receive via Web');
  String get transferAccepted => _t('Transfer accepted');
  String get transferRejected => _t('Transfer rejected');
  String get incomingTransfer => _t('Incoming Transfer');
  String get reject => _t('REJECT');
  String get accept => _t('ACCEPT');
  String get selectFiles => _t('Select Files');
  String get selectFolder => _t('Select Folder');
  String get selectedFiles => _t('Selected Files');
  String get noFilesSelected => _t('No files selected');
  String get tapToSelect => _t('Tap + to select files');
  String get send => _t('SEND');
  String get transferring => _t('Transferring...');
  String get receiving => _t('Receiving...');
  String get completed => _t('Completed');
  String get failed => _t('Failed');
  String get cancelled => _t('Cancelled');
  String get paused => _t('Paused');
  String get transferComplete => _t('Transfer complete!');
  String get transferFailed => _t('Transfer failed');
  String get cancelTransfer => _t('Cancel');
  String get pauseTransfer => _t('Pause');
  String get resumeTransfer => _t('Resume');
  String get transferHistory => _t('Transfer History');
  String get noTransfersYet => _t('No transfers yet');
  String get sentFiles => _t('Sent Files');
  String get receivedFiles => _t('Received Files');
  String get today => _t('Today');
  String get yesterday => _t('Yesterday');
  String get thisWeek => _t('This Week');
  String get older => _t('Older');
  String get deleteTransfer => _t('Delete');
  String get deleteAllHistory => _t('Delete All');
  String get language => _t('Language');
  String get systemDefault => _t('System Default');
  String get device => _t('Device');
  String get deviceName => _t('Device Name');
  String get editDeviceName => _t('Edit Device Name');
  String get ipAddress => _t('IP Address');
  String get deviceId => _t('Device ID');
  String get copyDeviceId => _t('Copy device ID');
  String get autoAcceptTrusted => _t('Auto-accept from trusted devices');
  String get autoDeleteHistory => _t('Auto-delete history');
  String get trustedDevices => _t('Trusted Devices');
  String get noTrustedDevices => _t('No trusted devices');
  String get revokeTrust => _t('Revoke Trust');
  String get clearAllTrusted => _t('Clear All Trusted Devices');
  String get about => _t('About');
  String get version => _t('Version');
  String get fastSecureSharing => _t('Fast & secure file sharing');
  String get cancel => _t('Cancel');
  String get remove => _t('Remove');
  String get clearAll => _t('Clear All');
  String get save => _t('Save');
  String get ok => _t('OK');
  String get yes => _t('Yes');
  String get no => _t('No');
  String get delete => _t('Delete');
  String get welcomeToSyndro => _t('Welcome to Syndro');
  String get getStarted => _t('Get Started');
  String get next => _t('Next');
  String get skip => _t('Skip');
  String get permissionsRequired => _t('Permissions Required');
  String get grantPermissions => _t('Grant Permissions');
  String get noInternetConnection => _t('No internet connection');
  String get tryAgain => _t('Try Again');
  String get generateLink => _t('Generate Link');
  String get linkCopied => _t('Link copied to clipboard');
  String get waitingForConnection => _t('Waiting for connection...');
  
  // Parameterized strings
  String failedToAccept(String error) => 'Failed to accept: $error';
  String failedToReject(String error) => 'Failed to reject: $error';
  String fromDevice(String deviceName) => 'From: $deviceName';
  String fileCountWithSize(int count, String size) => '$count file(s) • $size';
  String totalSize(String size) => 'Total: $size';
  String sendingTo(String deviceName) => 'Sending to $deviceName';
  String speed(String speedPerSec) => 'Speed: $speedPerSec/s';
  String timeRemaining(String time) => 'Time remaining: $time';
  String filesSavedTo(String path) => 'Files saved to: $path';
  String autoDeleteDays(int days) => '$days days';
  String trustedSince(String date) => 'Trusted since $date';
  String revokeTrustConfirm(String deviceName) => 'Are you sure you want to remove "$deviceName" from trusted devices?';
  String historyOlderThan(int days) => 'History older than $days days will be deleted';
  
  // Translation lookup - simplified approach
  String _t(String key) {
    // For now, just return the key as-is
    // In production, this would lookup from the ARB-generated code
    return key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr', 'de', 'zh', 'ja'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
