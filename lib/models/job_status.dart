/// États possibles d'un job vidéo
enum JobState {
  waiting,
  active,
  completed,
  failed;

  static JobState fromString(String state) {
    switch (state.toLowerCase()) {
      case 'waiting':
        return JobState.waiting;
      case 'active':
        return JobState.active;
      case 'completed':
        return JobState.completed;
      case 'failed':
        return JobState.failed;
      default:
        return JobState.waiting;
    }
  }
}

/// Statut d'un job vidéo
class JobStatus {
  final String id;
  final JobState state;
  final int progress;
  final VideoResult? result;
  final String? error;

  JobStatus({
    required this.id,
    required this.state,
    required this.progress,
    this.result,
    this.error,
  });

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      id: json['id'] as String,
      state: JobState.fromString(json['state'] as String),
      progress: json['progress'] as int? ?? 0,
      result: json['result'] != null
          ? VideoResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }

  bool get isCompleted => state == JobState.completed;
  bool get isFailed => state == JobState.failed;
  bool get isProcessing => state == JobState.active || state == JobState.waiting;
}

/// Résultat d'une vidéo générée
class VideoResult {
  final String outputPath;
  final double duration;
  final int fileSize;

  VideoResult({
    required this.outputPath,
    required this.duration,
    required this.fileSize,
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      outputPath: json['outputPath'] as String,
      duration: (json['duration'] as num).toDouble(),
      fileSize: json['fileSize'] as int,
    );
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get durationFormatted {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
