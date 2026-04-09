import 'package:flutter/material.dart';

enum VoiceLanguage { french, englishUS, englishGB, more }
enum VoiceStyle { professional, fun, storytelling }

class TTSConfig {
  VoiceLanguage language;
  VoiceStyle style;
  double speed;
  double volume;
  String text;
  
  TTSConfig({
    this.language = VoiceLanguage.french,
    this.style = VoiceStyle.professional,
    this.speed = 1.0,
    this.volume = 1.0,
    this.text = '',
  });
}

class TTSControlsWidget extends StatefulWidget {
  final TTSConfig initialConfig;
  final Function(TTSConfig) onConfigChanged;
  final VoidCallback? onGenerate;
  
  const TTSControlsWidget({
    Key? key,
    required this.initialConfig,
    required this.onConfigChanged,
    this.onGenerate,
  }) : super(key: key);

  @override
  _TTSControlsWidgetState createState() => _TTSControlsWidgetState();
}

class _TTSControlsWidgetState extends State<TTSControlsWidget> {
  late TTSConfig config;
  final TextEditingController _textController = TextEditingController();
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    config = widget.initialConfig;
    _textController.text = config.text;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateConfig() {
    config.text = _textController.text;
    widget.onConfigChanged(config);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              const Text(
                '🎙️ Voix IA (TTS)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white70),
                onPressed: _showHelp,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Text input
          TextField(
            controller: _textController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Entrez le texte à vocaliser...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              counterText: '${_textController.text.length} caractères',
              counterStyle: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onChanged: (_) {
              setState(() {});
              _updateConfig();
            },
          ),
          const SizedBox(height: 16),

          // Language selection
          const Text(
            'Langue:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildLanguageChip('🇫🇷 Français', VoiceLanguage.french),
              _buildLanguageChip('🇺🇸 English US', VoiceLanguage.englishUS),
              _buildLanguageChip('🇬🇧 English UK', VoiceLanguage.englishGB),
              _buildLanguageChip('🌍 Mooré', VoiceLanguage.more),
            ],
          ),
          const SizedBox(height: 16),

          // Voice style selection
          const Text(
            'Style de voix:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildStyleChip('💼 Professionnel', VoiceStyle.professional, Icons.business_center),
              _buildStyleChip('😄 Fun', VoiceStyle.fun, Icons.emoji_emotions),
              _buildStyleChip('📖 Storytelling', VoiceStyle.storytelling, Icons.auto_stories),
            ],
          ),
          const SizedBox(height: 16),

          // Speed control
          Row(
            children: [
              const Text('Vitesse:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Expanded(
                child: Slider(
                  value: config.speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${config.speed.toStringAsFixed(1)}x',
                  activeColor: Colors.purple,
                  onChanged: (value) {
                    setState(() {
                      config.speed = value;
                    });
                    _updateConfig();
                  },
                ),
              ),
              Text(
                '${config.speed.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Volume control
          Row(
            children: [
              const Text('Volume:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Expanded(
                child: Slider(
                  value: config.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(config.volume * 100).toInt()}%',
                  activeColor: Colors.purple,
                  onChanged: (value) {
                    setState(() {
                      config.volume = value;
                    });
                    _updateConfig();
                  },
                ),
              ),
              Text(
                '${(config.volume * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getConfigSummary(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Generate button
          if (widget.onGenerate != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _textController.text.isEmpty || isGenerating
                    ? null
                    : () async {
                        setState(() => isGenerating = true);
                        await Future.delayed(const Duration(seconds: 2));
                        if (widget.onGenerate != null) {
                          widget.onGenerate!();
                        }
                        if (mounted) {
                          setState(() => isGenerating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Voix générée avec succès'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  isGenerating ? 'Génération en cours...' : 'Générer la voix',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, VoiceLanguage language) {
    final isSelected = config.language == language;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            config.language = language;
          });
          _updateConfig();
        }
      },
      selectedColor: Colors.purple,
      backgroundColor: Colors.grey[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
        fontSize: 13,
      ),
    );
  }

  Widget _buildStyleChip(String label, VoiceStyle style, IconData icon) {
    final isSelected = config.style == style;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[400]),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            config.style = style;
          });
          _updateConfig();
        }
      },
      selectedColor: Colors.purple,
      backgroundColor: Colors.grey[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
        fontSize: 13,
      ),
    );
  }

  String _getConfigSummary() {
    final langName = _getLanguageName(config.language);
    final styleName = _getStyleName(config.style);
    final charCount = _textController.text.length;
    
    return 'Langue: $langName • Style: $styleName • $charCount caractères';
  }

  String _getLanguageName(VoiceLanguage language) {
    switch (language) {
      case VoiceLanguage.french:
        return 'Français';
      case VoiceLanguage.englishUS:
        return 'English US';
      case VoiceLanguage.englishGB:
        return 'English UK';
      case VoiceLanguage.more:
        return 'Mooré';
    }
  }

  String _getStyleName(VoiceStyle style) {
    switch (style) {
      case VoiceStyle.professional:
        return 'Professionnel';
      case VoiceStyle.fun:
        return 'Fun';
      case VoiceStyle.storytelling:
        return 'Storytelling';
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('💡 Aide TTS', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voix IA (Text-to-Speech)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Convertit votre texte en voix naturelle avec Piper TTS.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                'Langues supportées:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text('• Français (FR)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('• English US', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('• English UK', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('• Mooré (langues africaines)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 16),
              Text(
                'Styles de voix:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text('• Professionnel: Ton neutre et clair', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('• Fun: Ton enjoué et dynamique', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('• Storytelling: Ton narratif', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 16),
              Text(
                'Contrôles:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text('• Vitesse: 0.5x (lent) à 2.0x (rapide)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('• Volume: 0% (muet) à 100% (max)', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
