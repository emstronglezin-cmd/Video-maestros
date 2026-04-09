import 'package:flutter/material.dart';
import '../widgets/tts_controls_widget.dart';

class TTSConfigScreen extends StatefulWidget {
  const TTSConfigScreen({Key? key}) : super(key: key);

  @override
  _TTSConfigScreenState createState() => _TTSConfigScreenState();
}

class _TTSConfigScreenState extends State<TTSConfigScreen> {
  TTSConfig currentConfig = TTSConfig();
  List<String> generatedVoices = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('🎙️ Configuration Voix IA'),
        actions: [
          if (generatedVoices.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${generatedVoices.length}'),
                child: const Icon(Icons.library_music),
              ),
              onPressed: _showGeneratedVoices,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade800, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voix IA Professionnelle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Créez des voix off naturelles avec Piper TTS',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TTS Controls
            TTSControlsWidget(
              initialConfig: currentConfig,
              onConfigChanged: (config) {
                setState(() {
                  currentConfig = config;
                });
              },
              onGenerate: _generateVoice,
            ),
            const SizedBox(height: 24),

            // Features
            const Text(
              '✨ Fonctionnalités',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              Icons.language,
              'Multi-langues',
              'Français, Anglais US/UK, Mooré',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildFeatureCard(
              Icons.mic,
              '3 Styles de voix',
              'Professionnel, Fun, Storytelling',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildFeatureCard(
              Icons.tune,
              'Contrôles avancés',
              'Vitesse 0.5x-2.0x, Volume 0-100%',
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildFeatureCard(
              Icons.high_quality,
              'Qualité Premium',
              'Voix naturelles avec Piper TTS',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _generateVoice() {
    final timestamp = DateTime.now().toString();
    setState(() {
      generatedVoices.add('Voix_${generatedVoices.length + 1}_$timestamp');
    });
  }

  void _showGeneratedVoices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🎵 Voix Générées',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: generatedVoices.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.graphic_eq, color: Colors.white),
                    ),
                    title: Text(
                      'Voix ${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      generatedVoices[index].split('_').last,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.green),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('▶️ Lecture de la voix...')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              generatedVoices.removeAt(index);
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
