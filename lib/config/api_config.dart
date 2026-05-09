/**
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 🔗 API CONFIGURATION - VIDEO MAESTRO V3
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * Configuration centralisée pour toutes les URLs de l'API backend
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */

/// Configuration centralisée de l'API
class ApiConfig {
  /// Backend API URL - PRODUCTION RENDER.COM
  static const String production = 'https://video-maestros.onrender.com';
  
  /// Backend local pour développement
  static const String development = 'http://localhost:3000';
  
  /// URL de base du backend (utilise production par défaut)
  static const String baseUrl = production;
  
  /// Timeout par défaut pour les requêtes HTTP (30 secondes)
  static const Duration defaultTimeout = Duration(seconds: 30);
  
  /// Timeout pour les uploads (5 minutes)
  static const Duration uploadTimeout = Duration(minutes: 5);
  
  /// Timeout pour la génération de vidéos (10 minutes)
  static const Duration videoGenerationTimeout = Duration(minutes: 10);
  
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 📍 ENDPOINTS API
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Health check
  static const String health = '/api/health';
  
  /// Upload de fichiers
  static const String upload = '/api/upload';
  
  /// Utilisateur
  static const String userMe = '/api/user/me';
  static const String userSetup = '/api/user/setup';
  static const String userUpdate = '/api/user/me';
  static const String userStats = '/api/video/stats';
  
  /// Vidéo
  static const String videoParseScript = '/api/video/parse-script';
  static const String videoCreate = '/api/video/create';
  static const String videoStatus = '/api/video/status'; // + /:jobId
  static const String videoList = '/api/video/list';
  
  /// V3 - Features avancées
  static const String captionGenerate = '/api/caption/generate';
  static const String templates = '/api/templates';
  static const String batchCreate = '/api/batch/create';
  static const String socialAccounts = '/api/social/accounts';
  static const String marketplace = '/api/marketplace';
  
  /// V3 - TTS (Text-to-Speech)
  static const String ttsGenerate = '/api/v3/tts/generate';
  static const String ttsVoices = '/api/v3/tts/voices';
  
  /// Publicités Start.io
  static const String adsConfig = '/api/ads/config';
  static const String adsImpression = '/api/ads/impression';
  
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 🔧 HELPERS
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Construire une URL complète
  static String buildUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  /// Construire une URL de statut de vidéo
  static String buildVideoStatusUrl(String jobId) {
    return '$baseUrl$videoStatus/$jobId';
  }
  
  /// Construire une URL de téléchargement de vidéo
  static String buildVideoDownloadUrl(String outputPath) {
    return '$baseUrl/outputs/$outputPath';
  }
  
  /// Vérifier si l'API est en mode production
  static bool get isProduction => baseUrl == production;
  
  /// Vérifier si l'API est en mode développement
  static bool get isDevelopment => baseUrl == development;
  
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 📊 CONFIGURATION START.IO
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Prix de l'abonnement Premium (FCFA)
  static const int premiumPrice = 2000;
  
  /// Monnaie
  static const String currency = 'FCFA';
  
  /// Start.io Publisher ID (à configurer)
  /// Créer un compte sur https://portal.start.io/
  static const String startIoPublisherId = 'YOUR_PUBLISHER_ID';
  
  /// Activer les publicités Start.io
  static const bool startIoEnabled = true;
  
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 📝 INFORMATIONS
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  /// Nom de l'application
  static const String appName = 'Video Maestro';
  
  /// Version de l'API
  static const String apiVersion = 'v3';
  
  /// Support email
  static const String supportEmail = 'support@videomaestro.app';
  
  /// URL du site web
  static const String websiteUrl = 'https://videomaestro.app';
}
