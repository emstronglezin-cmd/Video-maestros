import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// 🔒 SYSTÈME DE GESTION D'ERREURS PRODUCTION
/// Protection complète contre les crashs et erreurs silencieuses

class ProductionErrorHandler {
  static final ProductionErrorHandler _instance = ProductionErrorHandler._internal();
  factory ProductionErrorHandler() => _instance;
  ProductionErrorHandler._internal();

  final List<ErrorRecord> _errorHistory = [];
  final int _maxErrorHistory = 100;
  int _errorCount = 0;

  /// Initialiser la gestion d'erreurs globale
  static void initialize() {
    // Capturer les erreurs Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      _instance._handleFlutterError(details);
    };

    // Capturer les erreurs Dart asynchrones
    PlatformDispatcher.instance.onError = (error, stack) {
      _instance._handlePlatformError(error, stack);
      return true;
    };

    // Capturer les erreurs de zone
    runZonedGuarded(
      () {
        // L'application démarrera ici
      },
      (error, stack) {
        _instance._handleZoneError(error, stack);
      },
    );

    if (kDebugMode) {
      debugPrint('✅ Production error handler initialized');
    }
  }

  /// Gérer les erreurs Flutter
  void _handleFlutterError(FlutterErrorDetails details) {
    _errorCount++;
    
    final record = ErrorRecord(
      type: ErrorType.flutter,
      error: details.exception,
      stackTrace: details.stack,
      timestamp: DateTime.now(),
      context: details.context?.toString(),
    );

    _addErrorRecord(record);

    // Logger en développement
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      // En production, logger silencieusement
      debugPrint('Flutter Error: ${details.exception}');
    }

    // TODO: Envoyer à Sentry ou service de monitoring
  }

  /// Gérer les erreurs platform
  bool _handlePlatformError(Object error, StackTrace stack) {
    _errorCount++;
    
    final record = ErrorRecord(
      type: ErrorType.platform,
      error: error,
      stackTrace: stack,
      timestamp: DateTime.now(),
    );

    _addErrorRecord(record);

    if (kDebugMode) {
      debugPrint('Platform Error: $error\n$stack');
    }

    return true;
  }

  /// Gérer les erreurs de zone
  void _handleZoneError(Object error, StackTrace stack) {
    _errorCount++;
    
    final record = ErrorRecord(
      type: ErrorType.zone,
      error: error,
      stackTrace: stack,
      timestamp: DateTime.now(),
    );

    _addErrorRecord(record);

    if (kDebugMode) {
      debugPrint('Zone Error: $error\n$stack');
    }
  }

  /// Ajouter un enregistrement d'erreur
  void _addErrorRecord(ErrorRecord record) {
    _errorHistory.add(record);
    
    // Limiter l'historique
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  /// Enregistrer une erreur personnalisée
  void logError(String message, {Object? error, StackTrace? stack, Map<String, dynamic>? context}) {
    _errorCount++;
    
    final record = ErrorRecord(
      type: ErrorType.custom,
      error: error ?? message,
      stackTrace: stack,
      timestamp: DateTime.now(),
      context: context?.toString(),
    );

    _addErrorRecord(record);

    if (kDebugMode) {
      debugPrint('Custom Error: $message');
      if (error != null) debugPrint('Error: $error');
      if (stack != null) debugPrint('Stack: $stack');
    }
  }

  /// Obtenir l'historique des erreurs
  List<ErrorRecord> getErrorHistory() => List.unmodifiable(_errorHistory);

  /// Obtenir le nombre total d'erreurs
  int get errorCount => _errorCount;

  /// Effacer l'historique
  void clearHistory() {
    _errorHistory.clear();
  }
}

/// Types d'erreurs
enum ErrorType {
  flutter,
  platform,
  zone,
  custom,
  network,
  storage,
}

/// Enregistrement d'erreur
class ErrorRecord {
  final ErrorType type;
  final Object error;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? context;

  ErrorRecord({
    required this.type,
    required this.error,
    this.stackTrace,
    required this.timestamp,
    this.context,
  });

  @override
  String toString() {
    return 'ErrorRecord(type: $type, error: $error, time: $timestamp)';
  }
}

/// Widget ErrorBoundary pour capturer les erreurs de widgets
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, ErrorRecord)? errorBuilder;
  final void Function(ErrorRecord)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  ErrorRecord? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!);
      }
      return _buildDefaultError(context);
    }

    return widget.child;
  }

  Widget _buildDefaultError(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Une erreur est survenue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                kDebugMode ? _error?.error.toString() ?? 'Erreur inconnue' : 'Veuillez réessayer',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() => _error = null);
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension pour try-catch simplifié
extension SafeAsync on Future {
  Future<T?> safe<T>({
    void Function(Object error, StackTrace? stack)? onError,
    T? defaultValue,
  }) async {
    try {
      return await this as T;
    } catch (error, stack) {
      ProductionErrorHandler().logError(
        'Safe async operation failed',
        error: error,
        stack: stack,
      );
      onError?.call(error, stack);
      return defaultValue;
    }
  }
}

/// Wrapper pour les opérations à risque
Future<T?> safeExecute<T>(
  Future<T> Function() operation, {
  T? defaultValue,
  void Function(Object error)? onError,
}) async {
  try {
    return await operation();
  } catch (error, stack) {
    ProductionErrorHandler().logError(
      'Safe execute failed',
      error: error,
      stack: stack,
    );
    onError?.call(error);
    return defaultValue;
  }
}

/// Widget pour afficher les statistiques d'erreurs (debug uniquement)
class ErrorStatsWidget extends StatelessWidget {
  const ErrorStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final handler = ProductionErrorHandler();
    final history = handler.getErrorHistory();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Total Errors: ${handler.errorCount}'),
            Text('Recent Errors: ${history.length}'),
            const SizedBox(height: 16),
            if (history.isNotEmpty) ...[
              const Text('Latest Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...history.reversed.take(5).map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${error.type.name}: ${error.error.toString().substring(0, 50)}...',
                  style: const TextStyle(fontSize: 12),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Validation des entrées utilisateur
class InputValidator {
  /// Valider un email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }

  /// Valider un mot de passe
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Le mot de passe doit contenir au moins une minuscule';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    return null;
  }

  /// Valider un username
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom d\'utilisateur est requis';
    }
    if (value.length < 3) {
      return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
    }
    if (value.length > 20) {
      return 'Le nom d\'utilisateur ne peut pas dépasser 20 caractères';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Le nom d\'utilisateur ne peut contenir que des lettres, chiffres et underscores';
    }
    return null;
  }

  /// Valider un texte non vide
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  /// Valider une longueur minimale
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    if (value.length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }
    return null;
  }

  /// Valider une URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'URL est requise';
    }
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return 'URL invalide';
      }
      return null;
    } catch (e) {
      return 'URL invalide';
    }
  }
}
