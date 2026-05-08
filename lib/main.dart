import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'services/firebase_auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_page_screen.dart';
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
      }
      
      runApp(const VideoMaestroApp());
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

class VideoMaestroApp extends StatelessWidget {
  const VideoMaestroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: ChangeNotifierProvider(
        create: (_) => AppProvider()..initialize(),
        child: MaterialApp(
          title: 'Video Maestro',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF667EEA),
              primary: const Color(0xFF667EEA),
              secondary: const Color(0xFF764BA2),
            ),
            useMaterial3: true,
            cardTheme: const CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/home': (context) => const HomeScreen(),
            '/profile': (context) => const ProfilePageScreen(),
          },
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

/// Wrapper pour gérer l'authentification
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: firebaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        // Chargement initial
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Utilisateur connecté
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Utilisateur non connecté
        return const LoginScreen();
      },
    );
  }
}
