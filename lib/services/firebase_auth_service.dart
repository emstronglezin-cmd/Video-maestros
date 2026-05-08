import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Service d'authentification Firebase production-ready
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  /// Stream des changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Obtenir le token ID pour les requêtes API
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return null;
    
    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération token: $e');
      }
      return null;
    }
  }

  /// Rafraîchir le token
  Future<String?> refreshToken() async {
    return await getIdToken(forceRefresh: true);
  }

  /// Inscription avec email et mot de passe
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mettre à jour le profil si displayName est fourni
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
        await credential.user?.reload();
      }

      // Envoyer email de vérification
      await credential.user?.sendEmailVerification();

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
  Future<UserCredential> signInWithEmail({
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

  /// Connexion avec Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Déclencher le flux d'authentification Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Connexion Google annulée');
      }

      // Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Créer les credentials Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Se connecter à Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      if (kDebugMode) {
        print('✅ Connexion Google réussie: ${userCredential.user?.email}');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur connexion Google: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue Google: $e');
      }
      throw Exception('Erreur lors de la connexion Google');
    }
  }

  /// Déconnexion complète (Firebase + Google)
  Future<void> signOut() async {
    try {
      // Déconnexion Google si connecté
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      // Déconnexion Firebase
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

  /// Renvoyer l'email de vérification
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        if (kDebugMode) {
          print('✅ Email de vérification envoyé');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur envoi email vérification: $e');
      }
      throw Exception('Erreur lors de l\'envoi de l\'email de vérification');
    }
  }

  /// Recharger les informations utilisateur
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur rechargement utilisateur: $e');
      }
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
      
      if (kDebugMode) {
        print('✅ Profil mis à jour');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour profil: $e');
      }
      throw Exception('Erreur lors de la mise à jour du profil');
    }
  }

  /// Changer le mot de passe
  Future<void> changePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      await user.updatePassword(newPassword);
      
      if (kDebugMode) {
        print('✅ Mot de passe changé');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur changement mot de passe: ${e.code}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue: $e');
      }
      throw Exception('Erreur lors du changement de mot de passe');
    }
  }

  /// Re-authentifier l'utilisateur (requis pour opérations sensibles)
  Future<void> reauthenticate(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      
      if (kDebugMode) {
        print('✅ Ré-authentification réussie');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ré-authentification: ${e.code}');
      }
      throw _handleAuthException(e);
    }
  }

  /// Supprimer le compte utilisateur
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      // Déconnexion Google si connecté
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
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

  /// Obtenir le nom d'affichage
  String? get displayName => currentUser?.displayName;

  /// Obtenir l'URL de la photo
  String? get photoURL => currentUser?.photoURL;

  /// Vérifier si l'email est vérifié
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Obtenir la date de création du compte
  DateTime? get creationTime => currentUser?.metadata.creationTime;

  /// Obtenir la date de dernière connexion
  DateTime? get lastSignInTime => currentUser?.metadata.lastSignInTime;

  /// Obtenir les providers d'authentification
  List<String> get providers {
    return currentUser?.providerData.map((p) => p.providerId).toList() ?? [];
  }

  /// Vérifier si connecté via Google
  bool get isGoogleSignIn => providers.contains('google.com');

  /// Vérifier si connecté via Email
  bool get isEmailSignIn => providers.contains('password');

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
      case 'invalid-credential':
        return 'Identifiants invalides';
      case 'account-exists-with-different-credential':
        return 'Un compte existe déjà avec cet email via un autre moyen de connexion';
      case 'credential-already-in-use':
        return 'Ces identifiants sont déjà utilisés par un autre compte';
      default:
        return e.message ?? 'Une erreur est survenue';
    }
  }
}

// Singleton
final firebaseAuthService = FirebaseAuthService();
