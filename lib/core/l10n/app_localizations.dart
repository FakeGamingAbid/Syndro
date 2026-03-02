import 'package:flutter/material.dart';

/// Helper class to get localized strings
/// Usage: AppLocalizations.of(context).devices
class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  // Translation maps
  static const Map<String, Map<String, String>> _translations = {
    'en': _englishStrings,
    'es': _spanishStrings,
    'zh': _chineseStrings,
    'ja': _japaneseStrings,
  };
  
  // English strings
  static const Map<String, String> _englishStrings = {
    'appTitle': 'Syndro',
    'devices': 'Devices',
    'history': 'History',
    'settings': 'Settings',
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
    'incomingTransfer': 'Incoming Transfer',
    'reject': 'REJECT',
    'accept': 'ACCEPT',
    'selectFiles': 'Select Files',
    'selectFolder': 'Select Folder',
    'selectedFiles': 'Selected Files',
    'noFilesSelected': 'No files selected',
    'tapToSelect': 'Tap + to select files',
    'send': 'SEND',
    'transferring': 'Transferring...',
    'receiving': 'Receiving...',
    'preparingFiles': 'Preparing files...',
    'encrypting': 'Encrypting...',
    'decrypting': 'Decrypting...',
    'completed': 'Completed',
    'failed': 'Failed',
    'cancelled': 'Cancelled',
    'paused': 'Paused',
    'resumed': 'Resumed',
    'transferComplete': 'Transfer complete!',
    'transferFailed': 'Transfer failed',
    'openFiles': 'Open Files',
    'openFolder': 'Open Folder',
    'cancelTransfer': 'Cancel',
    'pauseTransfer': 'Pause',
    'resumeTransfer': 'Resume',
    'transferHistory': 'Transfer History',
    'noTransfersYet': 'No transfers yet',
    'sentFiles': 'Sent Files',
    'receivedFiles': 'Received Files',
    'today': 'Today',
    'yesterday': 'Yesterday',
    'thisWeek': 'This Week',
    'older': 'Older',
    'deleteTransfer': 'Delete',
    'deleteAllHistory': 'Delete All',
    'confirmDelete': 'Are you sure you want to delete this transfer?',
    'confirmDeleteAll': 'Are you sure you want to delete all transfer history?',
    'language': 'Language',
    'systemDefault': 'System Default',
    'device': 'Device',
    'deviceName': 'Device Name',
    'editDeviceName': 'Edit Device Name',
    'deviceNameHint': 'This name will be visible to other devices on the network.',
    'ipAddress': 'IP Address',
    'deviceId': 'Device ID',
    'copyDeviceId': 'Copy device ID',
    'autoAcceptTrusted': 'Auto-accept from trusted devices',
    'autoAcceptTrustedDesc': 'Automatically accept transfers from devices you trust',
    'autoAcceptEnabled': 'Auto-accept enabled for trusted devices',
    'willAlwaysAsk': 'Will always ask for approval',
    'autoDeleteHistory': 'Auto-delete history',
    'autoDeleteDisabled': 'Disabled',
    'trustedDevices': 'Trusted Devices',
    'noTrustedDevices': 'No trusted devices',
    'revokeTrust': 'Revoke Trust',
    'clearAllTrusted': 'Clear All Trusted Devices',
    'clearAllTrustedConfirm': 'This will remove all devices from your trusted list.',
    'deviceRemoved': 'Device removed from trusted list',
    'allTrustedCleared': 'All trusted devices cleared',
    'about': 'About',
    'version': 'Version',
    'fastSecureSharing': 'Fast & secure file sharing',
    'cancel': 'Cancel',
    'remove': 'Remove',
    'clearAll': 'Clear All',
    'save': 'Save',
    'ok': 'OK',
    'yes': 'Yes',
    'no': 'No',
    'delete': 'Delete',
    'acceptTransfers': 'Accept transfers to add trusted devices',
    'languageChanged': 'Language changed. Restart app to fully apply.',
    'custom': 'Custom',
    'welcomeToSyndro': 'Welcome to Syndro',
    'getStarted': 'Get Started',
    'next': 'Next',
    'skip': 'Skip',
    'permissionsRequired': 'Permissions Required',
    'grantPermissions': 'Grant Permissions',
    'storagePermission': 'Storage Permission',
    'storagePermissionDesc': 'Syndro needs access to storage to send and receive files.',
    'notificationPermission': 'Notification Permission',
    'notificationPermissionDesc': 'Allow notifications to receive transfer updates.',
    'lanPermission': 'Local Network Permission',
    'lanPermissionDesc': 'Syndro needs local network access to discover nearby devices.',
    'allPermissionsGranted': 'All permissions granted',
    'noInternetConnection': 'No internet connection',
    'connectionError': 'Connection error',
    'serverError': 'Server error',
    'timeout': 'Request timed out',
    'tryAgain': 'Try Again',
    'generateLink': 'Generate Link',
    'linkGenerated': 'Link generated!',
    'copyLink': 'Copy Link',
    'linkCopied': 'Link copied to clipboard',
    'shareInBrowser': 'Share in Browser',
    'waitingForConnection': 'Waiting for connection...',
    'someoneJoined': 'Someone joined!',
    'sendFiles': 'Send Files',
    'downloadFiles': 'Download Files',
    'webShareDesc': 'Share files with devices that don\'t have Syndro installed',
  };
  
  // Spanish strings
  static const Map<String, String> _spanishStrings = {
    'appTitle': 'Syndro',
    'devices': 'Dispositivos',
    'history': 'Historial',
    'settings': 'Ajustes',
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
    'incomingTransfer': 'Transferencia entrante',
    'reject': 'RECHAZAR',
    'accept': 'ACEPTAR',
    'selectFiles': 'Seleccionar Archivos',
    'selectFolder': 'Seleccionar Carpeta',
    'selectedFiles': 'Archivos Seleccionados',
    'noFilesSelected': 'No hay archivos seleccionados',
    'tapToSelect': 'Toca + para seleccionar archivos',
    'send': 'ENVIAR',
    'transferring': 'Transfiriendo...',
    'receiving': 'Recibiendo...',
    'preparingFiles': 'Preparando archivos...',
    'encrypting': 'Cifrando...',
    'decrypting': 'Descifrando...',
    'completed': 'Completado',
    'failed': 'Fallido',
    'cancelled': 'Cancelado',
    'paused': 'Pausado',
    'resumed': 'Reanudado',
    'transferComplete': '¡Transferencia completada!',
    'transferFailed': 'Transferencia fallida',
    'openFiles': 'Abrir Archivos',
    'openFolder': 'Abrir Carpeta',
    'cancelTransfer': 'Cancelar',
    'pauseTransfer': 'Pausar',
    'resumeTransfer': 'Reanudar',
    'transferHistory': 'Historial de Transferencias',
    'noTransfersYet': 'Sin transferencias aún',
    'sentFiles': 'Archivos Enviados',
    'receivedFiles': 'Archivos Recibidos',
    'today': 'Hoy',
    'yesterday': 'Ayer',
    'thisWeek': 'Esta Semana',
    'older': 'Anteriores',
    'deleteTransfer': 'Eliminar',
    'deleteAllHistory': 'Eliminar Todo',
    'confirmDelete': '¿Estás seguro de que quieres eliminar esta transferencia?',
    'confirmDeleteAll': '¿Estás seguro de que quieres eliminar todo el historial?',
    'language': 'Idioma',
    'systemDefault': 'Predeterminado del Sistema',
    'device': 'Dispositivo',
    'deviceName': 'Nombre del Dispositivo',
    'editDeviceName': 'Editar Nombre del Dispositivo',
    'deviceNameHint': 'Este nombre será visible para otros dispositivos en la red.',
    'ipAddress': 'Dirección IP',
    'deviceId': 'ID del Dispositivo',
    'copyDeviceId': 'Copiar ID del dispositivo',
    'autoAcceptTrusted': 'Auto-aceptar de dispositivos de confianza',
    'autoAcceptTrustedDesc': 'Aceptar automáticamente transferencias de dispositivos de confianza',
    'autoAcceptEnabled': 'Auto-aceptar activado para dispositivos de confianza',
    'willAlwaysAsk': 'Siempre preguntará por aprobación',
    'autoDeleteHistory': 'Eliminar historial automáticamente',
    'autoDeleteDisabled': 'Desactivado',
    'trustedDevices': 'Dispositivos de Confianza',
    'noTrustedDevices': 'Sin dispositivos de confianza',
    'revokeTrust': 'Revocar Confianza',
    'clearAllTrusted': 'Borrar Todos los Dispositivos de Confianza',
    'clearAllTrustedConfirm': 'Esto eliminará todos los dispositivos de tu lista de confianza.',
    'deviceRemoved': 'Dispositivo eliminado de la lista de confianza',
    'allTrustedCleared': 'Todos los dispositivos de confianza eliminados',
    'about': 'Acerca de',
    'version': 'Versión',
    'fastSecureSharing': 'Compartición de archivos rápida y segura',
    'cancel': 'Cancelar',
    'remove': 'Eliminar',
    'clearAll': 'Borrar Todo',
    'save': 'Guardar',
    'ok': 'OK',
    'yes': 'Sí',
    'no': 'No',
    'delete': 'Eliminar',
    'acceptTransfers': 'Acepta transferencias para agregar dispositivos de confianza',
    'languageChanged': 'Idioma cambiado. Reinicia la aplicación para aplicar completamente.',
    'custom': 'Personalizado',
    'welcomeToSyndro': 'Bienvenido a Syndro',
    'getStarted': 'Comenzar',
    'next': 'Siguiente',
    'skip': 'Omitir',
    'permissionsRequired': 'Permisos Requeridos',
    'grantPermissions': 'Conceder Permisos',
    'storagePermission': 'Permiso de Almacenamiento',
    'storagePermissionDesc': 'Syndro necesita acceso al almacenamiento para enviar y recibir archivos.',
    'notificationPermission': 'Permiso de Notificaciones',
    'notificationPermissionDesc': 'Permite notificaciones para recibir actualizaciones de transferencia.',
    'lanPermission': 'Permiso de Red Local',
    'lanPermissionDesc': 'Syndro necesita acceso a la red local para descubrir dispositivos cercanos.',
    'allPermissionsGranted': 'Todos los permisos concedidos',
    'noInternetConnection': 'Sin conexión a internet',
    'connectionError': 'Error de conexión',
    'serverError': 'Error del servidor',
    'timeout': 'Tiempo de espera agotado',
    'tryAgain': 'Intentar de Nuevo',
    'generateLink': 'Generar Enlace',
    'linkGenerated': '¡Enlace generado!',
    'copyLink': 'Copiar Enlace',
    'linkCopied': 'Enlace copiado al portapapeles',
    'shareInBrowser': 'Compartir en Navegador',
    'waitingForConnection': 'Esperando conexión...',
    'someoneJoined': '¡Alguien se unió!',
    'sendFiles': 'Enviar Archivos',
    'downloadFiles': 'Descargar Archivos',
    'webShareDesc': 'Comparte archivos con dispositivos que no tienen Syndro instalado',
  };
  
  // Chinese strings
  static const Map<String, String> _chineseStrings = {
    'appTitle': 'Syndro',
    'devices': '设备',
    'history': '历史',
    'settings': '设置',
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
    'incomingTransfer': '传入传输',
    'reject': '拒绝',
    'accept': '接受',
    'selectFiles': '选择文件',
    'selectFolder': '选择文件夹',
    'selectedFiles': '已选文件',
    'noFilesSelected': '未选择文件',
    'tapToSelect': '点击 + 选择文件',
    'send': '发送',
    'transferring': '传输中...',
    'receiving': '接收中...',
    'preparingFiles': '准备文件中...',
    'encrypting': '加密中...',
    'decrypting': '解密中...',
    'completed': '已完成',
    'failed': '失败',
    'cancelled': '已取消',
    'paused': '已暂停',
    'resumed': '已恢复',
    'transferComplete': '传输完成！',
    'transferFailed': '传输失败',
    'openFiles': '打开文件',
    'openFolder': '打开文件夹',
    'cancelTransfer': '取消',
    'pauseTransfer': '暂停',
    'resumeTransfer': '继续',
    'transferHistory': '传输历史',
    'noTransfersYet': '暂无传输',
    'sentFiles': '已发送文件',
    'receivedFiles': '已接收文件',
    'today': '今天',
    'yesterday': '昨天',
    'thisWeek': '本周',
    'older': '更早',
    'deleteTransfer': '删除',
    'deleteAllHistory': '删除全部',
    'confirmDelete': '确定要删除此传输吗？',
    'confirmDeleteAll': '确定要删除所有传输历史吗？',
    'language': '语言',
    'systemDefault': '系统默认',
    'device': '设备',
    'deviceName': '设备名称',
    'editDeviceName': '编辑设备名称',
    'deviceNameHint': '此名称将对网络中的其他设备可见。',
    'ipAddress': 'IP地址',
    'deviceId': '设备ID',
    'copyDeviceId': '复制设备ID',
    'autoAcceptTrusted': '自动接受可信设备',
    'autoAcceptTrustedDesc': '自动接受来自可信设备的传输',
    'autoAcceptEnabled': '已启用可信设备自动接受',
    'willAlwaysAsk': '将始终询问确认',
    'autoDeleteHistory': '自动删除历史',
    'autoDeleteDisabled': '已禁用',
    'trustedDevices': '可信设备',
    'noTrustedDevices': '无可信设备',
    'revokeTrust': '撤销信任',
    'clearAllTrusted': '清除所有可信设备',
    'clearAllTrustedConfirm': '这将移除您可信列表中的所有设备。',
    'deviceRemoved': '设备已从可信列表中移除',
    'allTrustedCleared': '所有可信设备已清除',
    'about': '关于',
    'version': '版本',
    'fastSecureSharing': '快速安全的文件共享',
    'cancel': '取消',
    'remove': '移除',
    'clearAll': '清除全部',
    'save': '保存',
    'ok': '确定',
    'yes': '是',
    'no': '否',
    'delete': '删除',
    'acceptTransfers': '接受传输以添加可信设备',
    'languageChanged': '语言已更改。重新启动应用以完全应用。',
    'custom': '自定义',
    'welcomeToSyndro': '欢迎使用Syndro',
    'getStarted': '开始使用',
    'next': '下一步',
    'skip': '跳过',
    'permissionsRequired': '需要权限',
    'grantPermissions': '授予权限',
    'storagePermission': '存储权限',
    'storagePermissionDesc': 'Syndro需要访问存储来发送和接收文件。',
    'notificationPermission': '通知权限',
    'notificationPermissionDesc': '允许通知以接收传输更新。',
    'lanPermission': '本地网络权限',
    'lanPermissionDesc': 'Syndro需要本地网络访问权限以发现附近设备。',
    'allPermissionsGranted': '所有权限已授予',
    'noInternetConnection': '无网络连接',
    'connectionError': '连接错误',
    'serverError': '服务器错误',
    'timeout': '请求超时',
    'tryAgain': '重试',
    'generateLink': '生成链接',
    'linkGenerated': '链接已生成！',
    'copyLink': '复制链接',
    'linkCopied': '链接已复制到剪贴板',
    'shareInBrowser': '在浏览器中分享',
    'waitingForConnection': '等待连接...',
    'someoneJoined': '有人加入了！',
    'sendFiles': '发送文件',
    'downloadFiles': '下载文件',
    'webShareDesc': '与未安装Syndro的设备共享文件',
  };
  
  // Japanese strings
  static const Map<String, String> _japaneseStrings = {
    'appTitle': 'Syndro',
    'devices': 'デバイス',
    'history': '履歴',
    'settings': '設定',
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
    'incomingTransfer': '着信転送',
    'reject': '拒否',
    'accept': '承諾',
    'selectFiles': 'ファイルを選択',
    'selectFolder': 'フォルダを選択',
    'selectedFiles': '選択されたファイル',
    'noFilesSelected': 'ファイルが選択されていません',
    'tapToSelect': '+をタップしてファイルを選択',
    'send': '送信',
    'transferring': '転送中...',
    'receiving': '受信中...',
    'preparingFiles': 'ファイルを準備中...',
    'encrypting': '暗号化中...',
    'decrypting': '復号化中...',
    'completed': '完了',
    'failed': '失敗',
    'cancelled': 'キャンセル',
    'paused': '一時停止',
    'resumed': '再開',
    'transferComplete': '転送完了！',
    'transferFailed': '転送失敗',
    'openFiles': 'ファイルを開く',
    'openFolder': 'フォルダを開く',
    'cancelTransfer': 'キャンセル',
    'pauseTransfer': '一時停止',
    'resumeTransfer': '再開',
    'transferHistory': '転送履歴',
    'noTransfersYet': '転送はまだありません',
    'sentFiles': '送信済みファイル',
    'receivedFiles': '受信済みファイル',
    'today': '今日',
    'yesterday': '昨日',
    'thisWeek': '今週',
    'older': 'それ以前',
    'deleteTransfer': '削除',
    'deleteAllHistory': 'すべて削除',
    'confirmDelete': 'この転送を削除してもよろしいですか？',
    'confirmDeleteAll': 'すべての転送履歴を削除してもよろしいですか？',
    'language': '言語',
    'systemDefault': 'システムデフォルト',
    'device': 'デバイス',
    'deviceName': 'デバイス名',
    'editDeviceName': 'デバイス名を編集',
    'deviceNameHint': 'この名前はネットワーク上の他のデバイスに表示されます。',
    'ipAddress': 'IPアドレス',
    'deviceId': 'デバイスID',
    'copyDeviceId': 'デバイスIDをコピー',
    'autoAcceptTrusted': '信頼されたデバイスから自動受信',
    'autoAcceptTrustedDesc': '信頼するデバイスからの転送を自動的に受信',
    'autoAcceptEnabled': '信頼されたデバイスの自動受信が有効',
    'willAlwaysAsk': '常に確認を求める',
    'autoDeleteHistory': '履歴を自動削除',
    'autoDeleteDisabled': '無効',
    'trustedDevices': '信頼されたデバイス',
    'noTrustedDevices': '信頼されたデバイスはありません',
    'revokeTrust': '信頼を撤回',
    'clearAllTrusted': 'すべての信頼されたデバイスをクリア',
    'clearAllTrustedConfirm': 'これにより信頼リストからすべてのデバイスが削除されます。',
    'deviceRemoved': 'デバイスが信頼リストから削除されました',
    'allTrustedCleared': 'すべての信頼されたデバイスがクリアされました',
    'about': '概要',
    'version': 'バージョン',
    'fastSecureSharing': '高速で安全なファイル共有',
    'cancel': 'キャンセル',
    'remove': '削除',
    'clearAll': 'すべてクリア',
    'save': '保存',
    'ok': 'OK',
    'yes': 'はい',
    'no': 'いいえ',
    'delete': '削除',
    'acceptTransfers': '転送を受け入れると信頼されたデバイスが追加されます',
    'languageChanged': '言語が変更されました。完全に適用するにはアプリを再起動してください。',
    'custom': 'カスタム',
    'welcomeToSyndro': 'Syndroへようこそ',
    'getStarted': '始める',
    'next': '次へ',
    'skip': 'スキップ',
    'permissionsRequired': '権限が必要です',
    'grantPermissions': '権限を付与',
    'storagePermission': 'ストレージ権限',
    'storagePermissionDesc': 'Syndroはファイル送受信のためにストレージへのアクセスが必要です。',
    'notificationPermission': '通知権限',
    'notificationPermissionDesc': '転送更新を受け取るために通知を許可します。',
    'lanPermission': 'ローカルネットワーク権限',
    'lanPermissionDesc': 'Syndroは附近のデバイスを検出するためにローカルネットワークへのアクセスが必要です。',
    'allPermissionsGranted': 'すべての権限が付与されました',
    'noInternetConnection': 'インターネット接続なし',
    'connectionError': '接続エラー',
    'serverError': 'サーバーエラー',
    'timeout': 'リクエストがタイムアウトしました',
    'tryAgain': '再試行',
    'generateLink': 'リンクを生成',
    'linkGenerated': 'リンクが生成されました！',
    'copyLink': 'リンクをコピー',
    'linkCopied': 'リンクがクリップボードにコピーされました',
    'shareInBrowser': 'ブラウザで共有',
    'waitingForConnection': '接続を待機中...',
    'someoneJoined': '誰かが参加しました！',
    'sendFiles': 'ファイルを送信',
    'downloadFiles': 'ファイルをダウンロード',
    'webShareDesc': 'Syndroがインストールされていないデバイスとファイルを共有',
  };
  
  String _t(String key) {
    final langCode = locale.languageCode;
    final langStrings = _translations[langCode] ?? _englishStrings;
    return langStrings[key] ?? _englishStrings[key] ?? key;
  }
  
  // Simple getters
  String get appTitle => _t('appTitle');
  String get devices => _t('devices');
  String get history => _t('history');
  String get settings => _t('settings');
  String get initializing => _t('initializing');
  String get scanningForDevices => _t('scanningForDevices');
  String get noDevicesFound => _t('noDevicesFound');
  String get noDevicesTip => _t('noDevicesTip');
  String get scanAgain => _t('scanAgain');
  String get errorDiscoveringDevices => _t('errorDiscoveringDevices');
  String get retry => _t('retry');
  String get shareViaWeb => _t('shareViaWeb');
  String get receiveViaWeb => _t('receiveViaWeb');
  String get transferAccepted => _t('transferAccepted');
  String get transferRejected => _t('transferRejected');
  String get incomingTransfer => _t('incomingTransfer');
  String get reject => _t('reject');
  String get accept => _t('accept');
  String get selectFiles => _t('selectFiles');
  String get selectFolder => _t('selectFolder');
  String get selectedFiles => _t('selectedFiles');
  String get noFilesSelected => _t('noFilesSelected');
  String get tapToSelect => _t('tapToSelect');
  String get send => _t('send');
  String get transferring => _t('transferring');
  String get receiving => _t('receiving');
  String get preparingFiles => _t('preparingFiles');
  String get encrypting => _t('encrypting');
  String get decrypting => _t('decrypting');
  String get completed => _t('completed');
  String get failed => _t('failed');
  String get cancelled => _t('cancelled');
  String get paused => _t('paused');
  String get resumed => _t('resumed');
  String get transferComplete => _t('transferComplete');
  String get transferFailed => _t('transferFailed');
  String get openFiles => _t('openFiles');
  String get openFolder => _t('openFolder');
  String get cancelTransfer => _t('cancelTransfer');
  String get pauseTransfer => _t('pauseTransfer');
  String get resumeTransfer => _t('resumeTransfer');
  String get transferHistory => _t('transferHistory');
  String get noTransfersYet => _t('noTransfersYet');
  String get sentFiles => _t('sentFiles');
  String get receivedFiles => _t('receivedFiles');
  String get today => _t('today');
  String get yesterday => _t('yesterday');
  String get thisWeek => _t('thisWeek');
  String get older => _t('older');
  String get deleteTransfer => _t('deleteTransfer');
  String get deleteAllHistory => _t('deleteAllHistory');
  String get confirmDelete => _t('confirmDelete');
  String get confirmDeleteAll => _t('confirmDeleteAll');
  String get language => _t('language');
  String get systemDefault => _t('systemDefault');
  String get device => _t('device');
  String get deviceName => _t('deviceName');
  String get editDeviceName => _t('editDeviceName');
  String get deviceNameHint => _t('deviceNameHint');
  String get ipAddress => _t('ipAddress');
  String get deviceId => _t('deviceId');
  String get copyDeviceId => _t('copyDeviceId');
  String get autoAcceptTrusted => _t('autoAcceptTrusted');
  String get autoAcceptTrustedDesc => _t('autoAcceptTrustedDesc');
  String get autoAcceptEnabled => _t('autoAcceptEnabled');
  String get willAlwaysAsk => _t('willAlwaysAsk');
  String get autoDeleteHistory => _t('autoDeleteHistory');
  String get autoDeleteDisabled => _t('autoDeleteDisabled');
  String get trustedDevices => _t('trustedDevices');
  String get noTrustedDevices => _t('noTrustedDevices');
  String get revokeTrust => _t('revokeTrust');
  String get clearAllTrusted => _t('clearAllTrusted');
  String get clearAllTrustedConfirm => _t('clearAllTrustedConfirm');
  String get deviceRemoved => _t('deviceRemoved');
  String get allTrustedCleared => _t('allTrustedCleared');
  String get about => _t('about');
  String get version => _t('version');
  String get fastSecureSharing => _t('fastSecureSharing');
  String get cancel => _t('cancel');
  String get remove => _t('remove');
  String get clearAll => _t('clearAll');
  String get save => _t('save');
  String get ok => _t('ok');
  String get yes => _t('yes');
  String get no => _t('no');
  String get delete => _t('delete');
  String get acceptTransfers => _t('acceptTransfers');
  String get languageChanged => _t('languageChanged');
  String get custom => _t('custom');
  String get welcomeToSyndro => _t('welcomeToSyndro');
  String get getStarted => _t('getStarted');
  String get next => _t('next');
  String get skip => _t('skip');
  String get permissionsRequired => _t('permissionsRequired');
  String get grantPermissions => _t('grantPermissions');
  String get storagePermission => _t('storagePermission');
  String get storagePermissionDesc => _t('storagePermissionDesc');
  String get notificationPermission => _t('notificationPermission');
  String get notificationPermissionDesc => _t('notificationPermissionDesc');
  String get lanPermission => _t('lanPermission');
  String get lanPermissionDesc => _t('lanPermissionDesc');
  String get allPermissionsGranted => _t('allPermissionsGranted');
  String get noInternetConnection => _t('noInternetConnection');
  String get connectionError => _t('connectionError');
  String get serverError => _t('serverError');
  String get timeout => _t('timeout');
  String get tryAgain => _t('tryAgain');
  String get generateLink => _t('generateLink');
  String get linkGenerated => _t('linkGenerated');
  String get copyLink => _t('copyLink');
  String get linkCopied => _t('linkCopied');
  String get shareInBrowser => _t('shareInBrowser');
  String get waitingForConnection => _t('waitingForConnection');
  String get someoneJoined => _t('someoneJoined');
  String get sendFiles => _t('sendFiles');
  String get downloadFiles => _t('downloadFiles');
  String get webShareDesc => _t('webShareDesc');
  
  // Parameterized getters
  String failedToAccept(String error) => '${_t('failedToAccept')}: $error';
  String failedToReject(String error) => '${_t('failedToReject')}: $error';
  String fromDevice(String deviceName) => _t('fromDevice').replaceAll('{deviceName}', deviceName);
  String fileCountWithSize(int count, String size) => _t('fileCountWithSize').replaceAll('{count}', '$count').replaceAll('{size}', size);
  String totalSize(String size) => _t('totalSize').replaceAll('{size}', size);
  String sendingTo(String deviceName) => _t('sendingTo').replaceAll('{deviceName}', deviceName);
  String speed(String speedPerSec) => _t('speed').replaceAll('{speed}', speedPerSec);
  String timeRemaining(String time) => _t('timeRemaining').replaceAll('{time}', time);
  String filesSavedTo(String path) => _t('filesSavedTo').replaceAll('{path}', path);
  String autoDeleteDays(int days) => _t('autoDeleteDays').replaceAll('{days}', '$days');
  String trustedSince(String date) => _t('trustedSince').replaceAll('{date}', date);
  String revokeTrustConfirm(String deviceName) => _t('revokeTrustConfirm').replaceAll('{deviceName}', deviceName);
  String historyOlderThan(int days) => _t('historyOlderThan').replaceAll('{days}', '$days');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'zh', 'ja'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
