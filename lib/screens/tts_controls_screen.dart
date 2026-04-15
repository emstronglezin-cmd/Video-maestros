import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

enum TTSLanguage { fr, en }
enum TTSVoiceStyle { professional, fun, storytelling }

class TTSControlsScreen extends StatefulWidget {
  const TTSControlsScreen({Key? key}) : super(key: key);

  @override
  _TTSControlsScreenState createState() => _TTSControlsScreenState();
}

class _TTSControlsScreenState extends State<TTSControlsScreen> {
  final TextEditingController _textController = TextEditingController();
  TTSLanguage _selectedLanguage = TTSLanguage.fr;
  TTSVoiceStyle _selectedStyle = TTSVoiceStyle.professional;
  double _speed = 1.0;
  double _volume = 1.0;
  bool _isGenerating = false;
  String? _generatedAudioPath;
  String? _errorMessage;

  final Map<TTSLanguage, String> _languageLabels = {
    TTSLanguage.fr: '🇫🇷 Français',
    TTSLanguage.en: '🇬🇧 English',
  };

  final Map<TTSVoiceStyle, Map<String, dynamic>> _styleInfo = {
    TTSVoiceStyle.professional: {
      'label': 'Professionnel',
      'icon': Icons.business,
      'description': 'Voix claire et posée pour narrations professionnelles',
    },
    TTSVoiceStyle.fun: {
      'label': 'Fun',
      'icon': Icons.emoji_emotions,
      'description': 'Voix dynamique et énergique pour contenu viral',
    },
    TTSVoiceStyle.storytelling: {
      'label': 'Storytelling',
      'icon': Icons.auto_stories,
      'description': 'Voix expressive pour narrations captivantes',
    },
  };

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateTTS() async {
    if (_textController.text.trim().isEmpty) {
      _showError('Veuillez entrer un texte');
      return;
    }

    if (_textController.text.length > 5000) {
      _showError('Le texte ne doit pas dépasser 5000 caractères');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedAudioPath = null;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final apiService = appProvider.apiService;

      final response = await apiService.generateTTS(
        text: _textController.text,
        language: _selectedLanguage.name,
        style: _selectedStyle.name,
        speed: _speed,
        volume: _volume,
      );

      if (response['success'] == true) {
        setState(() {
          _generatedAudioPath = response['audioPath'];
          _isGenerating = false;
        });
        _showSuccess('Audio généré avec succès!');
      } else {
        throw Exception(response['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showError('Erreur: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('🎤 Synthèse Vocale (TTS)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Générez des voix-off professionnelles avec Piper TTS (Open Source)',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Text input
              _buildSection(
                title: '📝 Texte à synthétiser',
                child: TextField(
                  controller: _textController,
                  maxLines: 6,
                  maxLength: 5000,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Entrez votre texte ici...\n\nExemple: "Bienvenue sur Video Maestro, l\'application de montage vidéo IA la plus avancée!"',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Language selection
              _buildSection(
                title: '🌐 Langue',
                child: Wrap(
                  spacing: 12,
                  children: TTSLanguage.values.map((language) {
                    final isSelected = _selectedLanguage == language;
                    return ChoiceChip(
                      label: Text(_languageLabels[language]!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedLanguage = language);
                      },
                      selectedColor: Colors.purple,
                      backgroundColor: Colors.grey[800],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Voice style selection
              _buildSection(
                title: '🎭 Style de voix',
                child: Column(
                  children: TTSVoiceStyle.values.map((style) {
                    final isSelected = _selectedStyle == style;
                    final info = _styleInfo[style]!;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedStyle = style);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple.withValues(alpha: 0.3) : Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: Colors.purple, width: 2) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              info['icon'] as IconData,
                              color: isSelected ? Colors.purple : Colors.white70,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info['label'] as String,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    info['description'] as String,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Colors.purple),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Speed control
              _buildSection(
                title: '⚡ Vitesse de lecture',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          '${_speed.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text('Rapide', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    Slider(
                      value: _speed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      activeColor: Colors.purple,
                      inactiveColor: Colors.grey[700],
                      onChanged: (value) {
                        setState(() => _speed = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Volume control
              _buildSection(
                title: '🔊 Volume',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.volume_down, color: Colors.white70, size: 20),
                        Text(
                          '${(_volume * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Icon(Icons.volume_up, color: Colors.white70, size: 20),
                      ],
                    ),
                    Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: Colors.purple,
                      inactiveColor: Colors.grey[700],
                      onChanged: (value) {
                        setState(() => _volume = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Generated audio info
              if (_generatedAudioPath != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '✅ Audio généré avec succès!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fichier: $_generatedAudioPath',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Generate button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateTTS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isGenerating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Génération en cours...',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Générer la voix-off',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Tech info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Technologie utilisée',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Moteur: Piper TTS (100% Open Source)\n'
                      '• Qualité: HD (16kHz-48kHz)\n'
                      '• Langues: Français, English\n'
                      '• Zero-cost: Aucun frais API',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
