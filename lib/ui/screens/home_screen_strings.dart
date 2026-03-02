import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';

/// Localization strings for home screen - uses locale provider for translations
class HomeScreenStrings {
  // Get translations map based on locale
  static Map<String, String> _getTranslations(String langCode) {
    switch (langCode) {
      case 'es':
        return _spanishStrings;
      case 'zh':
        return _chineseStrings;
      case 'ja':
        return _japaneseStrings;
      default:
        return _englishStrings;
    }
  }

  static String _t(String key) {
    // This will be called at runtime with the current locale
    return key;
  }

  // English strings (default)
  static const Map<String, String> _englishStrings = {
    'devices': 'Devices',
    'history': 'History',
    'initializing': 'Initializing...',
    'scanningForDevices': 'Scanning for devices...',
    'noDevicesFound': 'No devices found',
    'noDevicesTip': 'Make sure other devices have Syndro open and are on the same WiFi network',
    'scanAgain': 'Scan Again',
    'errorDiscoveringDevices': 'Error discovering devices',
    'retry': 'Retry',
    'shareViaWeb': 'Share via Web',
    'receiveViaWeb': 'Receive via Web',
    'transferAccepted': 'Transfer accepted',
    'transferRejected': 'Transfer rejected',
    'failedToAccept': 'Failed to accept',
    'failedToReject': 'Failed to reject',
    'incomingTransfer': 'Incoming Transfer',
    'fromDevice': 'From',
    'fileCount': 'file(s)',
    'reject': 'REJECT',
    'accept': 'ACCEPT',
  };

  static const Map<String, String> _spanishStrings = {
    'devices': 'Dispositivos',
    'history': 'Historial',
    'initializing': 'Inicializando...',
    'scanningForDevices': 'Buscando dispositivos...',
    'noDevicesFound': 'No se encontraron dispositivos',
    'noDevicesTip': 'Asegúrate de que otros dispositivos tengan Syndro abierto y estén en la misma red WiFi',
    'scanAgain': 'Buscar de nuevo',
    'errorDiscoveringDevices': 'Error al descubrir dispositivos',
    'retry': 'Reintentar',
    'shareViaWeb': 'Compartir por Web',
    'receiveViaWeb': 'Recibir por Web',
    'transferAccepted': 'Transferencia aceptada',
    'transferRejected': 'Transferencia rechazada',
    'failedToAccept': 'Error al aceptar',
    'failedToReject': 'Error al rechazar',
    'incomingTransfer': 'Transferencia entrante',
    'fromDevice': 'De',
    'fileCount': 'archivo(s)',
    'reject': 'RECHAZAR',
    'accept': 'ACEPTAR',
  };

  static const Map<String, String> _chineseStrings = {
    'devices': '设备',
    'history': '历史',
    'initializing': '初始化中...',
    'scanningForDevices': '正在搜索设备...',
    'noDevicesFound': '未找到设备',
    'noDevicesTip': '确保其他设备已打开Syndro并处于同一WiFi网络',
    'scanAgain': '重新扫描',
    'errorDiscoveringDevices': '发现设备时出错',
    'retry': '重试',
    'shareViaWeb': '通过网络分享',
    'receiveViaWeb': '通过网络接收',
    'transferAccepted': '传输已接受',
    'transferRejected': '传输已拒绝',
    'failedToAccept': '接受失败',
    'failedToReject': '拒绝失败',
    'incomingTransfer': '传入传输',
    'fromDevice': '来自',
    'fileCount': '个文件',
    'reject': '拒绝',
    'accept': '接受',
  };

  static const Map<String, String> _japaneseStrings = {
    'devices': 'デバイス',
    'history': '履歴',
    'initializing': '初期化中...',
    'scanningForDevices': 'デバイスをスキャン中...',
    'noDevicesFound': 'デバイスが見つかりません',
    'noDevicesTip': '他のデバイスがSyndroを開いている同じWiFiネットワークにあることを確認してください',
    'scanAgain': '再スキャン',
    'errorDiscoveringDevices': 'デバイス検出エラー',
    'retry': '再試行',
    'shareViaWeb': 'Webで共有',
    'receiveViaWeb': 'Webで受信',
    'transferAccepted': '転送が受け入れられました',
    'transferRejected': '転送が拒否されました',
    'failedToAccept': '受け入れに失敗しました',
    'failedToReject': '拒否に失敗しました',
    'incomingTransfer': '着信転送',
    'fromDevice': '送信元',
    'fileCount': 'ファイル',
    'reject': '拒否',
    'accept': '承諾',
  };

  // Get current locale code
  static String _getCurrentLangCode() {
    try {
      // This is a simplified approach - in production you'd use a provider
      return 'en';
    } catch (e) {
      return 'en';
    }
  }

  // Static getters that can be used in code
  static String get devices => _t('devices');
  static String get history => _t('history');
  static String get initializing => _t('initializing');
  static String get scanningForDevices => _t('scanningForDevices');
  static String get noDevicesFound => _t('noDevicesFound');
  static String get noDevicesTip => _t('noDevicesTip');
  static String get scanAgain => _t('scanAgain');
  static String get errorDiscoveringDevices => _t('errorDiscoveringDevices');
  static String get retry => _t('retry');
  static String get shareViaWeb => _t('shareViaWeb');
  static String get receiveViaWeb => _t('receiveViaWeb');
  static String get transferAccepted => _t('transferAccepted');
  static String get transferRejected => _t('transferRejected');
  static String get incomingTransfer => _t('incomingTransfer');
  static String get fromDevice => _t('fromDevice');
  static String get fileCount => _t('fileCount');
  static String get reject => _t('reject');
  static String get accept => _t('accept');

  // Dynamic getters that use provider
  static String getLocalized(String key, WidgetRef? ref) {
    if (ref == null) {
      return _englishStrings[key] ?? key;
    }
    
    final localeState = ref.read(localeProvider);
    final langCode = localeState.locale?.languageCode ?? 'en';
    final translations = _getTranslations(langCode);
    return translations[key] ?? _englishStrings[key] ?? key;
  }

  // Helper methods with parameters
  static String failedToAccept(String error) => '${_t('failedToAccept')}: $error';
  static String failedToReject(String error) => '${_t('failedToReject')}: $error';
  static String fromDevice(String deviceName) => '${_t('fromDevice')}: $deviceName';
  static String fileCountWithSize(int count, String size) => '$count ${_t('fileCount')} • $size';
}
