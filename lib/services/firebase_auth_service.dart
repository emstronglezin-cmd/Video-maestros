import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service d'authentification Firebase
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  /// Stream des changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Obtenir le token ID pour les requêtes API
  Future<String?> getIdToken() async {
    final user = currentUser;
    if (user == null) return null;
    
    try {
      return await user.getIdToken();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération token: $e');
      }
      return null;
    }
  }

  /// Inscription avec email et mot de passe
  Future<UserCredential?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Inscription réussie: ${credential.user?.email}');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inscription: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue: $e');
      }
      throw Exception('Erreur lors de l\'inscription');
    }
  }

  /// Connexion avec email et mot de passe
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Connexion réussie: ${credential.user?.email}');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur connexion: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue: $e');
      }
      throw Exception('Erreur lors de la connexion');
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) {
        print('✅ Déconnexion réussie');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur déconnexion: $e');
      }
      throw Exception('Erreur lors de la déconnexion');
    }
  }

  /// Envoyer email de réinitialisation de mot de passe
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (kDebugMode) {
        print('✅ Email de réinitialisation envoyé à: $email');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur envoi email: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue: $e');
      }
      throw Exception('Erreur lors de l\'envoi de l\'email');
    }
  }

  /// Supprimer le compte utilisateur
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      await user.delete();
      if (kDebugMode) {
        print('✅ Compte supprimé');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression compte: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue: $e');
      }
      throw Exception('Erreur lors de la suppression du compte');
    }
  }

  /// Vérifier si l'utilisateur est connecté
  bool get isSignedIn => currentUser != null;

  /// Obtenir l'email de l'utilisateur
  String? get userEmail => currentUser?.email;

  /// Obtenir l'UID de l'utilisateur
  String? get userId => currentUser?.uid;

  /// Gestion des exceptions Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (minimum 6 caractères)';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email';
      case 'invalid-email':
        return 'L\'adresse email est invalide';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      case 'operation-not-allowed':
        return 'Opération non autorisée';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion';
      case 'requires-recent-login':
        return 'Veuillez vous reconnecter pour effectuer cette action';
      default:
        return e.message ?? 'Une erreur est survenue';
    }
  }
}

// Singleton
final firebaseAuthService = FirebaseAuthService();
