import 'package:flutter/material.dart';
import 'dart:async';

enum BatchJobStatus { pending, processing, completed, failed }

class BatchJob {
  final String jobId;
  final String name;
  BatchJobStatus status;
  int progress;
  final DateTime createdAt;
  DateTime? completedAt;
  
  BatchJob({
    required this.jobId,
    required this.name,
    this.status = BatchJobStatus.pending,
    this.progress = 0,
    required this.createdAt,
    this.completedAt,
  });
}

class BatchDashboardScreen extends StatefulWidget {
  const BatchDashboardScreen({Key? key}) : super(key: key);

  @override
  _BatchDashboardScreenState createState() => _BatchDashboardScreenState();
}

class _BatchDashboardScreenState extends State<BatchDashboardScreen> {
  List<BatchJob> jobs = [];
  Timer? _refreshTimer;
  String? sessionId;

  @override
  void initState() {
    super.initState();
    _createBatchSession();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && jobs.any((j) => j.status == BatchJobStatus.processing)) {
        _refreshJobStatus();
      }
    });
  }

  Future<void> _createBatchSession() async {
    // Mock session creation
    setState(() {
      sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  Future<void> _refreshJobStatus() async {
    // Mock refresh - simulate progress
    setState(() {
      for (var job in jobs) {
        if (job.status == BatchJobStatus.processing && job.progress < 100) {
          job.progress = (job.progress + 10).clamp(0, 100);
          if (job.progress >= 100) {
            job.status = BatchJobStatus.completed;
            job.completedAt = DateTime.now();
          }
        }
      }
    });
  }

  Future<void> _addJob() async {
    final newJob = BatchJob(
      jobId: 'job-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Vidéo ${jobs.length + 1}',
      createdAt: DateTime.now(),
    );

    setState(() {
      jobs.add(newJob);
    });

    // Auto-start after 1s
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        newJob.status = BatchJobStatus.processing;
      });
    }
  }

  int get completedCount => jobs.where((j) => j.status == BatchJobStatus.completed).length;
  int get failedCount => jobs.where((j) => j.status == BatchJobStatus.failed).length;
  int get processingCount => jobs.where((j) => j.status == BatchJobStatus.processing).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('📊 Batch Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: jobs.length < 10 ? _addJob : null,
            tooltip: 'Ajouter un job (max 10)',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats cards
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    jobs.length.toString(),
                    Icons.video_library,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'En cours',
                    processingCount.toString(),
                    Icons.hourglass_empty,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Terminés',
                    completedCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Échoués',
                    failedCount.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          // Jobs list
          Expanded(
            child: jobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_outlined,
                            size: 80, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun job en cours',
                          style: TextStyle(color: Colors.grey[500], fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Appuyez sur + pour ajouter un job',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      return _buildJobCard(jobs[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: jobs.isNotEmpty && jobs.length < 10
          ? FloatingActionButton.extended(
              onPressed: _addJob,
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.add),
              label: Text('Ajouter (${jobs.length}/10)'),
            )
          : null,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BatchJob job) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildJobStatusIcon(job.status),
        title: Text(
          job.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _getStatusText(job.status),
              style: TextStyle(color: _getStatusColor(job.status), fontSize: 13),
            ),
            if (job.status == BatchJobStatus.processing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: job.progress / 100,
                backgroundColor: Colors.grey[700],
                color: Colors.purple,
              ),
              const SizedBox(height: 4),
              Text(
                '${job.progress}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTime(job.createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        trailing: job.status == BatchJobStatus.processing ||
                job.status == BatchJobStatus.pending
            ? IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _cancelJob(job),
              )
            : null,
      ),
    );
  }

  Widget _buildJobStatusIcon(BatchJobStatus status) {
    switch (status) {
      case BatchJobStatus.pending:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.schedule, color: Colors.white, size: 20),
        );
      case BatchJobStatus.processing:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        );
      case BatchJobStatus.completed:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white, size: 20),
        );
      case BatchJobStatus.failed:
        return const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.error, color: Colors.white, size: 20),
        );
    }
  }

  String _getStatusText(BatchJobStatus status) {
    switch (status) {
      case BatchJobStatus.pending:
        return 'En attente...';
      case BatchJobStatus.processing:
        return 'Traitement en cours...';
      case BatchJobStatus.completed:
        return '✅ Terminé';
      case BatchJobStatus.failed:
        return '❌ Échec';
    }
  }

  Color _getStatusColor(BatchJobStatus status) {
    switch (status) {
      case BatchJobStatus.pending:
        return Colors.grey;
      case BatchJobStatus.processing:
        return Colors.orange;
      case BatchJobStatus.completed:
        return Colors.green;
      case BatchJobStatus.failed:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes}min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute}';
    }
  }

  void _cancelJob(BatchJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Annuler le job?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Voulez-vous annuler "${job.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                job.status = BatchJobStatus.failed;
                job.completedAt = DateTime.now();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Job "${job.name}" annulé'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}
