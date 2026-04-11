import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/**
 * Global Error Handler
 * Capture toutes les erreurs Flutter pour stabilité maximale
 */

class AppError {
  final String message;
  final String? stackTrace;
  final DateTime timestamp;
  final String? context;
  
  AppError({
    required this.message,
    this.stackTrace,
    required this.timestamp,
    this.context,
  });
  
  @override
  String toString() {
    return 'AppError: $message at $timestamp${context != null ? " (Context: $context)" : ""}';
  }
}

class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();
  
  final List<AppError> _errors = [];
  final int _maxErrors = 100;
  
  StreamController<AppError>? _errorController;
  Stream<AppError>? _errorStream;
  
  /// Initialize global error handling
  void initialize() {
    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };
    
    // Capture async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };
    
    // Initialize error stream
    _errorController = StreamController<AppError>.broadcast();
    _errorStream = _errorController!.stream;
    
    if (kDebugMode) {
      debugPrint('✅ Global Error Handler initialized');
    }
  }
  
  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    final error = AppError(
      message: details.exception.toString(),
      stackTrace: details.stack?.toString(),
      timestamp: DateTime.now(),
      context: details.context?.toString(),
    );
    
    _recordError(error);
    
    if (kDebugMode) {
      debugPrint('🔥 Flutter Error: ${error.message}');
      debugPrint('Stack: ${error.stackTrace}');
    }
    
    // Show error in debug mode
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }
  
  /// Handle platform/async errors
  void _handlePlatformError(Object error, StackTrace stack) {
    final appError = AppError(
      message: error.toString(),
      stackTrace: stack.toString(),
      timestamp: DateTime.now(),
    );
    
    _recordError(appError);
    
    if (kDebugMode) {
      debugPrint('🔥 Platform Error: ${appError.message}');
      debugPrint('Stack: ${appError.stackTrace}');
    }
  }
  
  /// Record error with size limit
  void _recordError(AppError error) {
    _errors.add(error);
    _errorController?.add(error);
    
    if (_errors.length > _maxErrors) {
      _errors.removeAt(0);
    }
  }
  
  /// Manually log an error
  void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? context,
  }) {
    final appError = AppError(
      message: message,
      stackTrace: stackTrace?.toString() ?? error?.toString(),
      timestamp: DateTime.now(),
      context: context,
    );
    
    _recordError(appError);
    
    if (kDebugMode) {
      debugPrint('📝 Logged Error: $message');
      if (error != null) debugPrint('Details: $error');
    }
  }
  
  /// Get all recorded errors
  List<AppError> getErrors() => List.unmodifiable(_errors);
  
  /// Get error stream for real-time monitoring
  Stream<AppError>? get errorStream => _errorStream;
  
  /// Clear all errors
  void clearErrors() {
    _errors.clear();
    if (kDebugMode) {
      debugPrint('🧹 Errors cleared');
    }
  }
  
  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    final now = DateTime.now();
    final last24h = _errors.where((e) => 
      now.difference(e.timestamp).inHours < 24
    ).length;
    
    final lastHour = _errors.where((e) =>
      now.difference(e.timestamp).inMinutes < 60
    ).length;
    
    return {
      'total': _errors.length,
      'last24h': last24h,
      'lastHour': lastHour,
      'oldestError': _errors.isNotEmpty ? _errors.first.timestamp : null,
      'newestError': _errors.isNotEmpty ? _errors.last.timestamp : null,
    };
  }
  
  /// Dispose resources
  void dispose() {
    _errorController?.close();
  }
}

/// Singleton instance
final globalErrorHandler = GlobalErrorHandler();

/// Error Widget with retry callback
class ErrorDisplayWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? details;
  
  const ErrorDisplayWidget({
    Key? key,
    required this.message,
    this.onRetry,
    this.details,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            'Erreur',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (details != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text(
                'Détails techniques',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    details!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// App-wide error boundary widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  
  const ErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
  }) : super(key: key);
  
  @override
  _ErrorBoundaryState createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  
  @override
  void initState() {
    super.initState();
    
    // Listen to error stream
    globalErrorHandler.errorStream?.listen((error) {
      if (mounted && _error == null) {
        setState(() {
          _error = error.message;
          _stackTrace = error.stackTrace != null 
            ? StackTrace.fromString(error.stackTrace!) 
            : null;
        });
      }
    });
  }
  
  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, _stackTrace);
      }
      
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: ErrorDisplayWidget(
          message: _error.toString(),
          details: _stackTrace?.toString(),
          onRetry: _retry,
        ),
      );
    }
    
    return widget.child;
  }
}

/// Input validation helpers
class InputValidator {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }
  
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email est requis';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    
    return null;
  }
  
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }
    return null;
  }
  
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value != null && value.length > maxLength) {
      return '$fieldName ne peut pas dépasser $maxLength caractères';
    }
    return null;
  }
  
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (int.tryParse(value) == null && double.tryParse(value) == null) {
      return '$fieldName doit être un nombre';
    }
    
    return null;
  }
  
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL est requise';
    }
    
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return 'URL invalide';
      }
    } catch (e) {
      return 'URL invalide';
    }
    
    return null;
  }
}
