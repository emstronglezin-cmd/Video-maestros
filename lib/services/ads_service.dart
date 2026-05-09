/**
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 📺 START.IO ADS SERVICE - Flutter
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * Gestion des publicités Start.io pour utilisateurs gratuits
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Modèle de configuration des publicités
class AdsConfig {
  final bool showAds;
  final bool isPremium;
  final int subscriptionPrice;
  final String currency;
  final StartIoConfig? startIo;

  AdsConfig({
    required this.showAds,
    required this.isPremium,
    required this.subscriptionPrice,
    required this.currency,
    this.startIo,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      showAds: json['showAds'] ?? false,
      isPremium: json['isPremium'] ?? false,
      subscriptionPrice: json['subscriptionPrice'] ?? 2000,
      currency: 'FCFA',
      startIo: json['startIo'] != null 
          ? StartIoConfig.fromJson(json['startIo']) 
          : null,
    );
  }
}

/// Configuration Start.io
class StartIoConfig {
  final String publisherId;
  final bool enabled;
  final AdTypes adTypes;

  StartIoConfig({
    required this.publisherId,
    required this.enabled,
    required this.adTypes,
  });

  factory StartIoConfig.fromJson(Map<String, dynamic> json) {
    return StartIoConfig(
      publisherId: json['publisherId'] ?? '',
      enabled: json['enabled'] ?? false,
      adTypes: AdTypes.fromJson(json['adTypes'] ?? {}),
    );
  }
}

/// Types de publicités disponibles
class AdTypes {
  final bool banner;
  final bool interstitial;
  final bool video;

  AdTypes({
    required this.banner,
    required this.interstitial,
    required this.video,
  });

  factory AdTypes.fromJson(Map<String, dynamic> json) {
    return AdTypes(
      banner: json['banner'] ?? false,
      interstitial: json['interstitial'] ?? false,
      video: json['video'] ?? false,
    );
  }
}

/// Service de gestion des publicités
class AdsService {
  static final String _baseUrl = ApiConfig.baseUrl;
  String? _authToken;

  /// Configure le token d'authentification
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Headers pour les requêtes
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Récupérer la configuration des publicités
  Future<AdsConfig> getAdsConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl${ApiConfig.adsConfig}'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get ads config: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to get ads config');
      }

      return AdsConfig.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error getting ads config: $e');
    }
  }

  /// Tracker une impression publicitaire
  Future<void> trackImpression(String adType, String adId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl${ApiConfig.adsImpression}'),
        headers: _getHeaders(),
        body: json.encode({
          'adType': adType,
          'adId': adId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to track impression: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to track impression');
      }
    } catch (e) {
      // Ne pas bloquer l'application si le tracking échoue
      print('Warning: Failed to track ad impression: $e');
    }
  }

  /// Vérifier si l'utilisateur doit voir des publicités
  Future<bool> shouldShowAds() async {
    try {
      final config = await getAdsConfig();
      return config.showAds;
    } catch (e) {
      // Par défaut, afficher les publicités en cas d'erreur
      print('Warning: Failed to check ad status: $e');
      return true;
    }
  }

  /// Obtenir le prix de l'abonnement Premium
  Future<int> getPremiumPrice() async {
    try {
      final config = await getAdsConfig();
      return config.subscriptionPrice;
    } catch (e) {
      // Retourner le prix par défaut
      return ApiConfig.premiumPrice;
    }
  }
}
