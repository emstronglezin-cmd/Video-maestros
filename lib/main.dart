import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'utils/production_error_handler.dart';
import 'dart:async';

void main() async {
  // 🔒 Initialiser la gestion d'erreurs AVANT tout
  ProductionErrorHandler.initialize();
  
  // Exécuter l'app dans une zone protégée
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialiser Firebase
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialisé avec succès');
      } catch (e, stack) {
        debugPrint('❌ Erreur initialisation Firebase: $e');
        ProductionErrorHandler().logError(
          'Firebase initialization failed',
          error: e,
          stack: stack,
        );
        // On continue quand même pour permettre le développement sans Firebase
      }
      
      runApp(const MyApp());
    },
    (error, stack) {
      ProductionErrorHandler().logError(
        'Unhandled error in main zone',
        error: error,
        stack: stack,
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: ChangeNotifierProvider(
        create: (_) => AppProvider()..initialize(),
        child: MaterialApp(
          title: 'Video Maestro',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            cardTheme: const CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          home: const HomeScreen(),
          // Builder pour capturer les erreurs de navigation
          builder: (context, child) {
            return ErrorBoundary(
              onError: (error) {
                ProductionErrorHandler().logError(
                  'Navigation error',
                  error: error.error,
                  stack: error.stackTrace,
                );
              },
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
