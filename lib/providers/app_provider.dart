import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/timeline.dart';
import '../models/job_status.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';

/// Provider principal de l'application
class AppProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirebaseAuthService _authService = firebaseAuthService;

  // État
  final List<File> _selectedFiles = [];
  String _script = '';
  Timeline? _timeline;
  String? _currentJobId;
  JobStatus? _currentJobStatus;
  UserStats? _userStats;
  bool _isLoading = false;
  String? _error;
  String _userId = '';
  String _selectedResolution = '1080';

  // Getters
  List<File> get selectedFiles => _selectedFiles;
  String get script => _script;
  Timeline? get timeline => _timeline;
  String? get currentJobId => _currentJobId;
  JobStatus? get currentJobStatus => _currentJobStatus;
  UserStats? get userStats => _userStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get userId => _userId;
  String get selectedResolution => _selectedResolution;
  bool get isAuthenticated => _authService.isSignedIn;
  String? get userEmail => _authService.userEmail;

  /// Initialise le provider
  Future<void> initialize() async {
    // Attendre que Firebase soit prêt
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Configurer le listener d'authentification
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        _userId = user.uid;
        
        // Obtenir et configurer le token pour l'API
        final token = await _authService.getIdToken();
        if (token != null) {
          _apiService.setAuthToken(token);
        }
        
        await loadUserStats();
      } else {
        _userId = '';
        _apiService.setAuthToken(null);
        _userStats = null;
      }
      notifyListeners();
    });
    
    // Si déjà connecté, initialiser
    if (_authService.isSignedIn) {
      _userId = _authService.userId ?? '';
      final token = await _authService.getIdToken();
      if (token != null) {
        _apiService.setAuthToken(token);
      }
      await loadUserStats();
    }
    
    notifyListeners();
  }

  /// Rafraîchir le token API (appeler avant chaque requête importante)
  Future<void> refreshApiToken() async {
    if (_authService.isSignedIn) {
      final token = await _authService.getIdToken();
      if (token != null) {
        _apiService.setAuthToken(token);
      }
    }
  }

  /// Change la résolution
  void setResolution(String resolution) {
    _selectedResolution = resolution;
    notifyListeners();
  }

  /// Ajoute des fichiers
  void addFiles(List<File> files) {
    _selectedFiles.addAll(files);
    _error = null;
    notifyListeners();
  }

  /// Retire un fichier
  void removeFile(int index) {
    _selectedFiles.removeAt(index);
    notifyListeners();
  }

  /// Clear tous les fichiers
  void clearFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }

  /// Met à jour le script
  void updateScript(String newScript) {
    _script = newScript;
    _error = null;
    notifyListeners();
  }

  /// Upload les fichiers
  Future<List<String>> uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      throw Exception('Aucun fichier sélectionné');
    }

    // Rafraîchir le token avant l'upload
    await refreshApiToken();

    _setLoading(true);
    try {
      final uploadedFiles = await _apiService.uploadFiles(_selectedFiles);
      _setLoading(false);
      return uploadedFiles;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Parse le script
  Future<void> parseScript(List<String> availableFiles) async {
    if (_script.isEmpty) {
      throw Exception('Le script est vide');
    }

    // Rafraîchir le token avant le parsing
    await refreshApiToken();

    _setLoading(true);
    try {
      _timeline = await _apiService.parseScript(_script, availableFiles);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Crée la vidéo
  Future<String> createVideo() async {
    if (_timeline == null) {
      throw Exception('Timeline non générée');
    }

    // Rafraîchir le token avant la création
    await refreshApiToken();

    _setLoading(true);
    try {
      // Met à jour la résolution dans la timeline
      final updatedTimeline = Timeline(
        elements: _timeline!.elements,
        audio: _timeline!.audio,
        resolution: _selectedResolution,
        fps: _timeline!.fps,
      );

      _currentJobId = await _apiService.createVideo(
        userId: _userId,
        timeline: updatedTimeline,
      );

      _setLoading(false);
      return _currentJobId!;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Récupère le statut du job
  Future<void> fetchJobStatus() async {
    if (_currentJobId == null) return;

    try {
      _currentJobStatus = await _apiService.getJobStatus(_currentJobId!);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur récupération statut: $e');
      }
    }
  }

  /// Charge les stats utilisateur
  Future<void> loadUserStats() async {
    if (!_authService.isSignedIn) return;
    
    // Rafraîchir le token avant de charger les stats
    await refreshApiToken();
    
    try {
      _userStats = await _apiService.getUserStats(_userId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur récupération stats: $e');
      }
    }
  }

  /// Récupère l'URL de la vidéo
  String? getVideoUrl() {
    if (_currentJobStatus?.result == null) return null;
    return _apiService.getVideoUrl(_currentJobStatus!.result!.outputPath);
  }

  /// Reset pour une nouvelle vidéo
  void reset() {
    _selectedFiles.clear();
    _script = '';
    _timeline = null;
    _currentJobId = null;
    _currentJobStatus = null;
    _error = null;
    notifyListeners();
  }

  /// Vérifie la connexion backend
  Future<bool> checkBackendConnection() async {
    return await _apiService.checkHealth();
  }

  // Helpers privés
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
