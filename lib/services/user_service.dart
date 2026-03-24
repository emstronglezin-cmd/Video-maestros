import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';

/// Service pour la gestion des utilisateurs
class UserService {
  static const String baseUrl = 'https://video-maestros-production.up.railway.app';
  
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Récupère le profil utilisateur
  Future<UserProfile?> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/me'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 404) {
        // Profil non trouvé - besoin de configuration
        return null;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to get profile: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to get profile');
      }

      return UserProfile.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error getting profile: $e');
    }
  }

  /// Configuration initiale du profil (username)
  Future<UserProfile> setupProfile({
    required String username,
    String? displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/setup'),
        headers: _getHeaders(),
        body: json.encode({
          'username': username,
          if (displayName != null) 'displayName': displayName,
        }),
      );

      if (response.statusCode == 409) {
        throw Exception('Username already taken');
      }

      if (response.statusCode != 201) {
        throw Exception('Failed to setup profile: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to setup profile');
      }

      return UserProfile.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error setting up profile: $e');
    }
  }

  /// Met à jour le profil utilisateur
  Future<UserProfile> updateProfile({
    String? username,
    String? displayName,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/me'),
        headers: _getHeaders(),
        body: json.encode({
          if (username != null) 'username': username,
          if (displayName != null) 'displayName': displayName,
        }),
      );

      if (response.statusCode == 409) {
        throw Exception('Username already taken');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to update profile');
      }

      return UserProfile.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  /// Vérifie si un username est disponible
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/check-username/$username'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        return false;
      }

      return data['data']['available'] == true;
    } catch (e) {
      return false;
    }
  }
}
