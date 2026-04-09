import 'package:flutter/material.dart';

enum VoiceLanguage { french, englishUS, englishGB, moore }
enum VoiceStyle { professional, fun, storytelling }

class TTSConfig {
  VoiceLanguage language;
  VoiceStyle style;
  double speed;
  double volume;
  
  TTSConfig({
    this.language = VoiceLanguage.french,
    this.style = VoiceStyle.professional,
    this.speed = 1.0,
    this.volume = 1.0,
  });
}

class TTSControlsWidget extends StatefulWidget {
  final TTSConfig initialConfig;
  final Function(TTSConfig) onConfigChanged;
  final bool enabled;
  
  const TTSControlsWidget({
    Key? key,
    required this.initialConfig,
    required this.onConfigChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  _TTSControlsWidgetState createState() => _TTSControlsWidgetState();
}

class _TTSControlsWidgetState extends State<TTSControlsWidget> {
  late TTSConfig _config;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _updateConfig() {
    widget.onConfigChanged(_config);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: const Icon(Icons.record_voice_over, color: Colors.purple),
            title: const Text(
              '🎤 Voix AI (Text-to-Speech)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: widget.enabled
                ? Text(
                    '${_getLanguageLabel(_config.language)} • ${_getStyleLabel(_config.style)}',
                    style: const TextStyle(color: Colors.purple, fontSize: 12),
                  )
                : const Text(
                    'Désactivé',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.enabled)
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                  ),
              ],
            ),
          ),

          // Expanded controls
          if (_isExpanded && widget.enabled) ...[
            const Divider(color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language selector
                  const Text(
                    'Langue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: VoiceLanguage.values.map((lang) {
                      final isSelected = _config.language == lang;
                      return ChoiceChip(
                        label: Text(_getLanguageLabel(lang)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _config.language = lang;
                              _updateConfig();
                            });
                          }
                        },
                        selectedColor: Colors.purple,
                        backgroundColor: Colors.grey[800],
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Style selector
                  const Text(
                    'Style de voix',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...VoiceStyle.values.map((style) {
                    final isSelected = _config.style == style;
                    return RadioListTile<VoiceStyle>(
                      value: style,
                      groupValue: _config.style,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _config.style = value;
                            _updateConfig();
                          });
                        }
                      },
                      title: Row(
                        children: [
                          Icon(
                            _getStyleIcon(style),
                            color: isSelected ? Colors.purple : Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStyleLabel(style),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        _getStyleDescription(style),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      activeColor: Colors.purple,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),

                  const SizedBox(height: 20),

                  // Speed slider
                  const Text(
                    'Vitesse de lecture',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.speed, color: Colors.white54, size: 20),
                      Expanded(
                        child: Slider(
                          value: _config.speed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${_config.speed.toStringAsFixed(1)}x',
                          activeColor: Colors.purple,
                          inactiveColor: Colors.grey[700],
                          onChanged: (value) {
                            setState(() {
                              _config.speed = value;
                              _updateConfig();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${_config.speed.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lent',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                      Text(
                        'Normal',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                      Text(
                        'Rapide',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Volume slider
                  const Text(
                    'Volume',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _config.volume == 0
                            ? Icons.volume_off
                            : _config.volume < 0.5
                                ? Icons.volume_down
                                : Icons.volume_up,
                        color: Colors.white54,
                        size: 20,
                      ),
                      Expanded(
                        child: Slider(
                          value: _config.volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(_config.volume * 100).toInt()}%',
                          activeColor: Colors.purple,
                          inactiveColor: Colors.grey[700],
                          onChanged: (value) {
                            setState(() {
                              _config.volume = value;
                              _updateConfig();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${(_config.volume * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Preview button
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow, color: Colors.purple),
                      label: const Text(
                        'Aperçu vocal',
                        style: TextStyle(color: Colors.purple),
                      ),
                      onPressed: _previewVoice,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLanguageLabel(VoiceLanguage lang) {
    switch (lang) {
      case VoiceLanguage.french:
        return '🇫🇷 Français';
      case VoiceLanguage.englishUS:
        return '🇺🇸 English (US)';
      case VoiceLanguage.englishGB:
        return '🇬🇧 English (UK)';
      case VoiceLanguage.moore:
        return '🌍 Mooré';
    }
  }

  String _getStyleLabel(VoiceStyle style) {
    switch (style) {
      case VoiceStyle.professional:
        return 'Professionnel';
      case VoiceStyle.fun:
        return 'Amusant';
      case VoiceStyle.storytelling:
        return 'Narratif';
    }
  }

  String _getStyleDescription(VoiceStyle style) {
    switch (style) {
      case VoiceStyle.professional:
        return 'Voix claire et posée, idéale pour contenu éducatif';
      case VoiceStyle.fun:
        return 'Voix dynamique et enjouée, parfaite pour contenu viral';
      case VoiceStyle.storytelling:
        return 'Voix expressive et captivante pour raconter des histoires';
    }
  }

  IconData _getStyleIcon(VoiceStyle style) {
    switch (style) {
      case VoiceStyle.professional:
        return Icons.business_center;
      case VoiceStyle.fun:
        return Icons.celebration;
      case VoiceStyle.storytelling:
        return Icons.auto_stories;
    }
  }

  void _previewVoice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Row(
          children: [
            Icon(Icons.play_circle, color: Colors.purple),
            SizedBox(width: 8),
            Text('Aperçu vocal', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.purple),
            const SizedBox(height: 16),
            Text(
              'Génération de l\'aperçu...',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Langue: ${_getLanguageLabel(_config.language)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Text(
              'Style: ${_getStyleLabel(_config.style)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Text(
              'Vitesse: ${_config.speed.toStringAsFixed(1)}x',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    // Simulate preview generation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 Aperçu vocal joué avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}
