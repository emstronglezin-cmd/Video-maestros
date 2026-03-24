import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/firebase_auth_service.dart';
import 'home_screen.dart';

/// Écran de configuration du profil (username)
class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _userService = UserService();
  final _authService = FirebaseAuthService();
  
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.length < 3) return;

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final isAvailable = await _userService.isUsernameAvailable(username);
      setState(() {
        _usernameError = isAvailable ? null : 'Ce nom d\'utilisateur est déjà pris';
      });
    } catch (e) {
      // Ignore errors silently
    } finally {
      setState(() {
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameError != null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer le token Firebase
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();
      _userService.setAuthToken(token);

      // Créer le profil
      await _userService.setupProfile(
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
      );

      if (!mounted) return;

      // Navigation vers l'écran principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Erreur lors de la création du profil';
      if (e.toString().contains('already taken')) {
        errorMessage = 'Ce nom d\'utilisateur est déjà pris';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un nom d\'utilisateur';
    }

    if (value.length < 3) {
      return 'Minimum 3 caractères';
    }

    if (value.length > 30) {
      return 'Maximum 30 caractères';
    }

    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(value)) {
      return 'Lettres, chiffres et _ uniquement';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // Logo/Icon
                Icon(
                  Icons.person_add_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                
                const SizedBox(height: 24),
                
                // Titre
                Text(
                  'Bienvenue !',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Sous-titre
                Text(
                  'Choisissez votre nom d\'utilisateur',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // Champ username
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Nom d\'utilisateur',
                    hintText: 'ex: john_doe',
                    prefixIcon: const Icon(Icons.alternate_email),
                    suffixIcon: _isCheckingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameError != null
                            ? const Icon(Icons.error, color: Colors.red)
                            : _usernameController.text.length >= 3
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _usernameError,
                  ),
                  validator: _validateUsername,
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _checkUsernameAvailability(value.trim());
                    } else {
                      setState(() {
                        _usernameError = null;
                      });
                    }
                  },
                  textInputAction: TextInputAction.next,
                ),
                
                const SizedBox(height: 16),
                
                // Champ display name (optionnel)
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: 'Nom d\'affichage (optionnel)',
                    hintText: 'ex: John Doe',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitProfile(),
                ),
                
                const SizedBox(height: 32),
                
                // Bouton de validation
                FilledButton(
                  onPressed: _isLoading ? null : _submitProfile,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continuer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                
                const SizedBox(height: 24),
                
                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vous pourrez modifier ces informations plus tard dans votre profil',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
