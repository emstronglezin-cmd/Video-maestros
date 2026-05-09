import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/timeline.dart';
import '../models/job_status.dart';
import '../models/user_stats.dart';
import '../models/payment.dart';
import '../config/api_config.dart';

/// Service pour communiquer avec le backend Node.js
class ApiService {
  // URL du backend - PRODUCTION RENDER.COM
  // Configuration centralisée dans api_config.dart
  static final String baseUrl = ApiConfig.baseUrl;

  // Token Firebase pour authentification
  String? _authToken;

  /// Configure le token d'authentification
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Headers communs pour toutes les requêtes
  Map<String, String> _getHeaders({Map<String, String>? additional}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?additional,
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// Upload des fichiers
  Future<List<String>> uploadFiles(List<File> files) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload'),
      );

      // Ajouter le token d'authentification
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      for (final file in files) {
        request.files.add(
          await http.MultipartFile.fromPath('files', file.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload échoué: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Upload échoué');
      }

      final uploadedFiles = (data['data']['files'] as List)
          .map((f) => f['filename'] as String)
          .toList();

      return uploadedFiles;
    } catch (e) {
      throw Exception('Erreur upload: $e');
    }
  }

  /// Parse un script en timeline
  Future<Timeline> parseScript(String script, List<String> availableFiles) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/video/parse-script'),
        headers: _getHeaders(),
        body: json.encode({
          'script': script,
          'availableFiles': availableFiles,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Parse échoué: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Parse échoué');
      }

      return Timeline.fromJson(data['data']);
    } catch (e) {
      throw Exception('Erreur parsing: $e');
    }
  }

  /// Crée une vidéo
  Future<String> createVideo({
    required String userId,
    required Timeline timeline,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/video/create'),
        headers: _getHeaders(),
        body: json.encode({
          'userId': userId,
          'timeline': timeline.toJson(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Création échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Création échouée');
      }

      return data['data']['jobId'] as String;
    } catch (e) {
      throw Exception('Erreur création: $e');
    }
  }

  /// Récupère le statut d'un job
  Future<JobStatus> getJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/video/status/$jobId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 404) {
        throw Exception('Job non trouvé');
      }

      if (response.statusCode != 200) {
        throw Exception('Récupération statut échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Récupération échouée');
      }

      return JobStatus.fromJson(data['data']);
    } catch (e) {
      throw Exception('Erreur récupération statut: $e');
    }
  }

  /// Récupère les stats utilisateur
  Future<UserStats> getUserStats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/video/stats/$userId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Récupération stats échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Récupération échouée');
      }

      return UserStats.fromJson(data['data']);
    } catch (e) {
      throw Exception('Erreur récupération stats: $e');
    }
  }

  /// Télécharge la vidéo
  String getVideoUrl(String outputPath) {
    return '$baseUrl/$outputPath';
  }

  /// Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Génère du TTS avec Piper
  Future<Map<String, dynamic>> generateTTS({
    required String text,
    required String language,
    required String style,
    required double speed,
    required double volume,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v3/tts/generate'),
        headers: _getHeaders(),
        body: json.encode({
          'text': text,
          'language': language,
          'style': style,
          'speed': speed,
          'volume': volume,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('TTS génération échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'TTS génération échouée');
      }

      return data['data'];
    } catch (e) {
      throw Exception('Erreur TTS: $e');
    }
  }

  // ==================== GENIUSPAY PAYMENT METHODS ====================

  /// Crée un paiement GeniusPay
  Future<Payment> createPayment({
    required String userId,
    required double amount,
    required String currency,
    String? plan,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payment/create'),
        headers: _getHeaders(),
        body: json.encode({
          'userId': userId,
          'amount': amount,
          'currency': currency,
          'plan': plan,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Création paiement échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Création paiement échouée');
      }

      return Payment.fromJson(data['data']['payment']);
    } catch (e) {
      throw Exception('Erreur création paiement: $e');
    }
  }

  /// Vérifie le statut d'un paiement
  Future<Payment> getPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/payment/status/$paymentId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Récupération statut échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Récupération échouée');
      }

      return Payment.fromJson(data['data']['payment']);
    } catch (e) {
      throw Exception('Erreur récupération statut: $e');
    }
  }

  /// Récupère l'historique des paiements
  Future<List<Payment>> getPaymentHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/payment/history?userId=$userId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Récupération historique échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Récupération échouée');
      }

      final payments = (data['data']['payments'] as List)
          .map((p) => Payment.fromJson(p))
          .toList();

      return payments;
    } catch (e) {
      throw Exception('Erreur récupération historique: $e');
    }
  }

  /// Récupère le statut de l'abonnement utilisateur
  Future<UserSubscription> getSubscriptionStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/payment/subscription/status?userId=$userId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Récupération abonnement échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Récupération échouée');
      }

      return UserSubscription.fromJson(data['data']['subscription']);
    } catch (e) {
      throw Exception('Erreur récupération abonnement: $e');
    }
  }

  /// Demande un remboursement
  Future<bool> requestRefund(String paymentId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payment/refund/$paymentId'),
        headers: _getHeaders(),
        body: json.encode({
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Demande remboursement échouée: ${response.body}');
      }

      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      throw Exception('Erreur demande remboursement: $e');
    }
  }
}
