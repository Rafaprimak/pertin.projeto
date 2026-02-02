import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configurações do Firebase geradas a partir do google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não está configurado para esta plataforma.',
        );
    }
  }

  // Configuração Android (do google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBixP4uJWCdxpsaQYmLmb6i4Np6lawZ4Xk',
    appId: '1:367928943371:android:f82ee3f600cb882ed9380e',
    messagingSenderId: '367928943371',
    projectId: 'pertin-93a59',
    storageBucket: 'pertin-93a59.firebasestorage.app',
  );

  // Para Web, iOS, macOS, Windows e Linux - use as mesmas credenciais
  // NOTA: Para produção, você deve configurar credenciais específicas 
  // para cada plataforma no Firebase Console
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBixP4uJWCdxpsaQYmLmb6i4Np6lawZ4Xk',
    appId: '1:367928943371:android:f82ee3f600cb882ed9380e',
    messagingSenderId: '367928943371',
    projectId: 'pertin-93a59',
    storageBucket: 'pertin-93a59.firebasestorage.app',
    authDomain: 'pertin-93a59.firebaseapp.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBixP4uJWCdxpsaQYmLmb6i4Np6lawZ4Xk',
    appId: '1:367928943371:android:f82ee3f600cb882ed9380e',
    messagingSenderId: '367928943371',
    projectId: 'pertin-93a59',
    storageBucket: 'pertin-93a59.firebasestorage.app',
    iosBundleId: 'pertin.banco',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBixP4uJWCdxpsaQYmLmb6i4Np6lawZ4Xk',
    appId: '1:367928943371:android:f82ee3f600cb882ed9380e',
    messagingSenderId: '367928943371',
    projectId: 'pertin-93a59',
    storageBucket: 'pertin-93a59.firebasestorage.app',
    iosBundleId: 'pertin.banco',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBixP4uJWCdxpsaQYmLmb6i4Np6lawZ4Xk',
    appId: '1:367928943371:android:f82ee3f600cb882ed9380e',
    messagingSenderId: '367928943371',
    projectId: 'pertin-93a59',
    storageBucket: 'pertin-93a59.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyBixP4uJWCdxpsaQYmLmb6i4Np6lawZ4Xk',
    appId: '1:367928943371:android:f82ee3f600cb882ed9380e',
    messagingSenderId: '367928943371',
    projectId: 'pertin-93a59',
    storageBucket: 'pertin-93a59.firebasestorage.app',
  );
}
