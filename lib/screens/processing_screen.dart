import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/app_provider.dart';
import '../models/job_status.dart';

/// Écran de traitement de la vidéo
class ProcessingScreen extends StatefulWidget {
  final String jobId;

  const ProcessingScreen({super.key, required this.jobId});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Poll toutes les 2 secondes
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await provider.fetchJobStatus();

      if (provider.currentJobStatus != null) {
        if (provider.currentJobStatus!.isCompleted) {
          timer.cancel();
          if (mounted) {
            _showCompletionDialog();
          }
        } else if (provider.currentJobStatus!.isFailed) {
          timer.cancel();
          if (mounted) {
            _showErrorDialog();
          }
        }
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Vidéo prête !'),
          ],
        ),
        content: const Text('Votre vidéo a été créée avec succès.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Provider.of<AppProvider>(context, listen: false).reset();
            },
            child: const Text('Terminé'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final error = provider.currentJobStatus?.error ?? 'Erreur inconnue';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('Erreur'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traitement en cours'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final status = provider.currentJobStatus;

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (status == null || status.isProcessing) ...[
                      const CircularProgressIndicator(
                        strokeWidth: 6,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _getStatusText(status),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (status != null && status.progress > 0)
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: status.progress / 100,
                              minHeight: 8,
                            ),
                            const SizedBox(height: 8),
                            Text('${status.progress}%'),
                          ],
                        ),
                    ] else if (status.isCompleted) ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 80,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Vidéo créée avec succès !',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (status.result != null) ...[
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  Icons.timer,
                                  'Durée',
                                  status.result!.durationFormatted,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.storage,
                                  'Taille',
                                  status.result!.fileSizeFormatted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ] else if (status.isFailed) ...[
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 80,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Erreur lors du traitement',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        status.error ?? 'Erreur inconnue',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      'Job ID: ${widget.jobId.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(value),
      ],
    );
  }

  String _getStatusText(JobStatus? status) {
    if (status == null) return 'Initialisation...';

    switch (status.state) {
      case JobState.waiting:
        return 'En attente dans la file...';
      case JobState.active:
        return 'Montage en cours...';
      case JobState.completed:
        return 'Terminé !';
      case JobState.failed:
        return 'Échec';
    }
  }
}
