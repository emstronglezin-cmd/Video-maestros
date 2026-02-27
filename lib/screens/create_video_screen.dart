import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../widgets/file_card.dart';
import '../widgets/script_editor.dart';
import 'processing_screen.dart';

/// Écran de création de vidéo
class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  int _currentStep = 0;
  bool _isUploading = false;
  bool _isParsing = false;
  List<String> _uploadedFiles = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une vidéo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  if (details.stepIndex > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Retour'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(
                      details.stepIndex == 2 ? 'Créer la vidéo' : 'Continuer',
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Fichiers'),
              subtitle: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  return Text('${provider.selectedFiles.length} fichier(s)');
                },
              ),
              content: _buildFileStep(),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Script'),
              subtitle: const Text('Décrivez votre montage'),
              content: _buildScriptStep(),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Options'),
              subtitle: const Text('Qualité et paramètres'),
              content: _buildOptionsStep(),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileStep() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sélectionnez des vidéos, images et audio pour votre montage',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (provider.selectedFiles.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Aucun fichier sélectionné'),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.selectedFiles.length,
                itemBuilder: (context, index) {
                  return FileCard(
                    file: provider.selectedFiles[index],
                    onRemove: () => provider.removeFile(index),
                  );
                },
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter des fichiers'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScriptStep() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Décrivez le montage souhaité en langage naturel',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ScriptEditor(
              initialScript: provider.script,
              onChanged: (script) => provider.updateScript(script),
            ),
            const SizedBox(height: 8),
            Text(
              'Exemple: "Commence avec video1.mp4 pendant 5 secondes, '
              'ajoute une transition fade, puis image1.jpg pendant 3 secondes"',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsStep() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choisissez la qualité de la vidéo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildResolutionTile('720', 'HD (720p)', provider),
            _buildResolutionTile('1080', 'Full HD (1080p)', provider),
            _buildResolutionTile('2160', '4K (2160p)', provider),
            const SizedBox(height: 16),
            if (provider.userStats != null) ...[
              Card(
                color: provider.userStats!.isPremium
                    ? Colors.amber[50]
                    : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            provider.userStats!.isPremium
                                ? Icons.workspace_premium
                                : Icons.info_outline,
                            color: provider.userStats!.isPremium
                                ? Colors.amber
                                : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.userStats!.isPremium ? 'Premium' : 'Gratuit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Exports aujourd\'hui: ${provider.userStats!.todayExports}'),
                      Text('Restants: ${provider.userStats!.remainingExportsText}'),
                      Text('Résolution max: ${provider.userStats!.limits.maxResolutionText}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResolutionTile(String value, String label, AppProvider provider) {
    final isAllowed = provider.userStats != null &&
        int.parse(value) <= provider.userStats!.limits.maxResolution;

    return RadioListTile<String>(
      value: value,
      groupValue: provider.selectedResolution,
      onChanged: isAllowed
          ? (newValue) {
              if (newValue != null) {
                provider.setResolution(newValue);
              }
            }
          : null,
      title: Text(label),
      subtitle: !isAllowed
          ? const Text('Nécessite Premium', style: TextStyle(color: Colors.red))
          : null,
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
      );

      if (result != null) {
        final files = result.paths.map((path) => File(path!)).toList();
        if (mounted) {
          Provider.of<AppProvider>(context, listen: false).addFiles(files);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _onStepContinue() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    if (_currentStep == 0) {
      // Validation étape 1: fichiers
      if (provider.selectedFiles.isEmpty) {
        _showError('Veuillez sélectionner au moins un fichier');
        return;
      }

      // Upload des fichiers
      setState(() => _isUploading = true);
      try {
        _uploadedFiles = await provider.uploadFiles();
        setState(() {
          _isUploading = false;
          _currentStep = 1;
        });
      } catch (e) {
        setState(() => _isUploading = false);
        _showError('Erreur upload: $e');
      }
    } else if (_currentStep == 1) {
      // Validation étape 2: script
      if (provider.script.isEmpty) {
        _showError('Veuillez écrire un script');
        return;
      }

      // Parse du script
      setState(() => _isParsing = true);
      try {
        await provider.parseScript(_uploadedFiles);
        setState(() {
          _isParsing = false;
          _currentStep = 2;
        });
      } catch (e) {
        setState(() => _isParsing = false);
        _showError('Erreur parsing: $e');
      }
    } else if (_currentStep == 2) {
      // Création de la vidéo
      try {
        final jobId = await provider.createVideo();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ProcessingScreen(jobId: jobId),
            ),
          );
        }
      } catch (e) {
        _showError('Erreur création: $e');
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
