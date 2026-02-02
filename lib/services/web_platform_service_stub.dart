// Stub para plataformas não-web
// Este arquivo é usado quando o app roda em mobile (Android/iOS)

class WebPlatformService {
  static final WebPlatformService instance = WebPlatformService._init();
  
  WebPlatformService._init();

  Future<void> init() async {}
  
  Future<bool> requestNotificationPermission() async => false;
  
  Future<bool> requestWakeLock() async => false;
  
  void releaseWakeLock() {}
  
  Future<bool> showNotification(String title, String body, {String? tag}) async => false;
  
  void vibrate([List<int>? pattern]) {}
  
  void stopVibration() {}
  
  bool playAlarmSound() => false;
  
  void stopAlarmSound() {}
  
  Map<String, dynamic> getPlatformInfo() => {};
  
  bool isPageVisible() => true;
  
  void startKeepAlive() {}
  
  void stopKeepAlive() {}
  
  bool get isPWA => false;
  bool get isIOS => false;
  bool get hasNotificationPermission => false;
  bool get isWakeLockActive => false;
}
