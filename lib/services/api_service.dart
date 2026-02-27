import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/timeline.dart';
import '../models/job_status.dart';
import '../models/user_stats.dart';

/// Service pour communiquer avec le backend Node.js
class ApiService {
  // URL du backend - À CONFIGURER
  // Pour développement local : 'http://10.0.2.2:3000' (émulateur Android)
  // Pour appareil physique : 'http://192.168.1.X:3000' (remplacer X par votre IP)
  // Pour production : 'https://votre-serveur.com'
  static const String baseUrl = 'http://10.0.2.2:3000';

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
}
