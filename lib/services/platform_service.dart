import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class PlatformService {
  static bool get isWeb => kIsWeb;
  
  static bool get isDesktop {
    if (kIsWeb) return false;
    // Em ambiente web, não podemos usar dart:io
    return false;
  }
  
  static bool get isMobile {
    if (kIsWeb) return false;
    return true; // Assume mobile se não for web
  }
  
  // Firebase é inicializado no main.dart
  // Este método é mantido para compatibilidade
  static Future<void> initDatabase() async {
    debugPrint('Firebase Firestore será usado como banco de dados');
  }
}
