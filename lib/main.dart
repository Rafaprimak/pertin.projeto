import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pertin/firebase_options.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/providers/user_provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/screens/splash_screen.dart';
import 'package:pertin/services/encryption_service.dart';
import 'package:pertin/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase com as opções corretas para cada plataforma
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase inicializado com sucesso!');
    
    // Habilita persistência offline do Firestore
    // Isso permite que o app funcione mesmo sem internet
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('Firestore offline persistence habilitado!');
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase: $e');
    // Continua mesmo com erro do Firebase para não travar o app
  }
  
  // Inicializa o serviço de criptografia
  try {
    await EncryptionService.instance.init();
    debugPrint('EncryptionService inicializado com sucesso!');
  } catch (e) {
    debugPrint('Erro ao inicializar EncryptionService: $e');
  }
  
  // Inicializa dados de formatação de data para português
  await initializeDateFormatting('pt_BR', null);
  
  // Define a orientação do app (apenas mobile)
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      debugPrint('Erro ao definir orientação: $e');
    }
  }
  
  // Define o estilo da barra de status
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const PertinApp());
}

class PertinApp extends StatelessWidget {
  const PertinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
      ],
      child: MaterialApp(
        title: 'Pertin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
