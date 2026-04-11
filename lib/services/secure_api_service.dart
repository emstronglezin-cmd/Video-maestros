import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

/**
 * Service API Sécurisé avec Retry Logic et Error Handling
 * Pour stabilité et maintenabilité à long terme
 */

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  
  ApiException(this.message, {this.statusCode, this.errorCode});
  
  @override
  String toString() => 'ApiException: $message (Status: $statusCode, Code: $errorCode)';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}

class SecureApiService {
  final String baseUrl;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  
  // Circuit breaker
  int _consecutiveFailures = 0;
  final int _failureThreshold = 5;
  DateTime? _circuitOpenTime;
  final Duration _circuitRecoveryTime = const Duration(minutes: 1);
  
  SecureApiService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });
  
  /// Circuit breaker check
  bool get _isCircuitOpen {
    if (_circuitOpenTime == null) return false;
    
    final now = DateTime.now();
    if (now.difference(_circuitOpenTime!).inMilliseconds > _circuitRecoveryTime.inMilliseconds) {
      // Try to recover
      _circuitOpenTime = null;
      _consecutiveFailures = 0;
      return false;
    }
    
    return true;
  }
  
  void _recordSuccess() {
    _consecutiveFailures = 0;
    _circuitOpenTime = null;
  }
  
  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _failureThreshold) {
      _circuitOpenTime = DateTime.now();
      if (kDebugMode) {
        debugPrint('🚨 Circuit breaker OPEN - Too many failures');
      }
    }
  }
  
  /// GET request with retry logic
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    return _executeWithRetry(() => _doGet(endpoint, headers, queryParams));
  }
  
  /// POST request with retry logic
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _executeWithRetry(() => _doPost(endpoint, body, headers));
  }
  
  /// PUT request with retry logic
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _executeWithRetry(() => _doPut(endpoint, body, headers));
  }
  
  /// DELETE request with retry logic
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _executeWithRetry(() => _doDelete(endpoint, headers));
  }
  
  /// Execute request with retry logic
  Future<Map<String, dynamic>> _executeWithRetry(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (_isCircuitOpen) {
      throw NetworkException('Service temporarily unavailable (circuit breaker open)');
    }
    
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < maxRetries) {
      try {
        final result = await request();
        _recordSuccess();
        return result;
      } on SocketException catch (e) {
        lastException = NetworkException('No internet connection');
        attempts++;
        if (kDebugMode) {
          debugPrint('❌ Network error (attempt $attempts/$maxRetries): ${e.message}');
        }
      } on TimeoutException catch (e) {
        lastException = NetworkException('Request timeout');
        attempts++;
        if (kDebugMode) {
          debugPrint('⏱️ Timeout error (attempt $attempts/$maxRetries): ${e.message}');
        }
      } on http.ClientException catch (e) {
        lastException = NetworkException('Request failed: ${e.message}');
        attempts++;
        if (kDebugMode) {
          debugPrint('🔌 Client error (attempt $attempts/$maxRetries): ${e.message}');
        }
      } on ApiException catch (e) {
        // Don't retry 4xx errors (client errors)
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          _recordSuccess(); // Not a server failure
          rethrow;
        }
        lastException = e;
        attempts++;
        if (kDebugMode) {
          debugPrint('🔥 API error (attempt $attempts/$maxRetries): ${e.message}');
        }
      } catch (e) {
        lastException = Exception('Unexpected error: $e');
        attempts++;
        if (kDebugMode) {
          debugPrint('⚠️ Unexpected error (attempt $attempts/$maxRetries): $e');
        }
      }
      
      // Wait before retry
      if (attempts < maxRetries) {
        await Future.delayed(retryDelay * attempts); // Exponential backoff
      }
    }
    
    _recordFailure();
    throw lastException ?? Exception('Request failed after $maxRetries attempts');
  }
  
  /// Internal GET implementation
  Future<Map<String, dynamic>> _doGet(
    String endpoint,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  ) async {
    final uri = _buildUri(endpoint, queryParams);
    final response = await http.get(uri, headers: _mergeHeaders(headers))
        .timeout(timeout);
    
    return _handleResponse(response);
  }
  
  /// Internal POST implementation
  Future<Map<String, dynamic>> _doPost(
    String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  ) async {
    final uri = _buildUri(endpoint, null);
    final response = await http.post(
      uri,
      headers: _mergeHeaders(headers),
      body: body != null ? json.encode(body) : null,
    ).timeout(timeout);
    
    return _handleResponse(response);
  }
  
  /// Internal PUT implementation
  Future<Map<String, dynamic>> _doPut(
    String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  ) async {
    final uri = _buildUri(endpoint, null);
    final response = await http.put(
      uri,
      headers: _mergeHeaders(headers),
      body: body != null ? json.encode(body) : null,
    ).timeout(timeout);
    
    return _handleResponse(response);
  }
  
  /// Internal DELETE implementation
  Future<Map<String, dynamic>> _doDelete(
    String endpoint,
    Map<String, String>? headers,
  ) async {
    final uri = _buildUri(endpoint, null);
    final response = await http.delete(uri, headers: _mergeHeaders(headers))
        .timeout(timeout);
    
    return _handleResponse(response);
  }
  
  /// Build URI with query params
  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final url = '$baseUrl$path';
    
    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: queryParams);
    }
    
    return Uri.parse(url);
  }
  
  /// Merge headers with defaults
  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
  }
  
  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (kDebugMode) {
      debugPrint('📥 Response ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
    }
    
    // Success
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException('Invalid JSON response', statusCode: response.statusCode);
      }
    }
    
    // Error
    String message = 'Request failed';
    String? errorCode;
    
    try {
      final errorBody = json.decode(response.body) as Map<String, dynamic>;
      message = errorBody['error'] ?? errorBody['message'] ?? message;
      errorCode = errorBody['code'];
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : 'Request failed';
    }
    
    throw ApiException(
      message,
      statusCode: response.statusCode,
      errorCode: errorCode,
    );
  }
}

/// Singleton instance
final secureApiService = SecureApiService(
  baseUrl: 'https://video-maestros-production.up.railway.app',
  timeout: const Duration(seconds: 30),
  maxRetries: 3,
  retryDelay: const Duration(seconds: 2),
);
