/// Représente un élément de timeline vidéo
class TimelineElement {
  final String type;
  final String? file;
  final double duration;
  final double? volume;
  final String? content;
  final String? position;
  final String? effect;

  TimelineElement({
    required this.type,
    this.file,
    required this.duration,
    this.volume,
    this.content,
    this.position,
    this.effect,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type,
      'duration': duration,
    };

    if (file != null) data['file'] = file;
    if (volume != null) data['volume'] = volume;
    if (content != null) data['content'] = content;
    if (position != null) data['position'] = position;
    if (effect != null) data['effect'] = effect;

    return data;
  }

  factory TimelineElement.fromJson(Map<String, dynamic> json) {
    return TimelineElement(
      type: json['type'] as String,
      file: json['file'] as String?,
      duration: (json['duration'] as num).toDouble(),
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : null,
      content: json['content'] as String?,
      position: json['position'] as String?,
      effect: json['effect'] as String?,
    );
  }
}

/// Configuration audio
class AudioConfig {
  final String? file;
  final double volume;

  AudioConfig({
    this.file,
    this.volume = 0.5,
  });

  Map<String, dynamic> toJson() {
    return {
      if (file != null) 'file': file,
      'volume': volume,
    };
  }

  factory AudioConfig.fromJson(Map<String, dynamic> json) {
    return AudioConfig(
      file: json['file'] as String?,
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : 0.5,
    );
  }
}

/// Timeline complète
class Timeline {
  final List<TimelineElement> elements;
  final AudioConfig? audio;
  final String resolution;
  final int fps;

  Timeline({
    required this.elements,
    this.audio,
    this.resolution = '1080',
    this.fps = 30,
  });

  Map<String, dynamic> toJson() {
    return {
      'timeline': elements.map((e) => e.toJson()).toList(),
      if (audio != null) 'audio': audio!.toJson(),
      'resolution': resolution,
      'fps': fps,
    };
  }

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      elements: (json['timeline'] as List)
          .map((e) => TimelineElement.fromJson(e as Map<String, dynamic>))
          .toList(),
      audio: json['audio'] != null
          ? AudioConfig.fromJson(json['audio'] as Map<String, dynamic>)
          : null,
      resolution: json['resolution'] as String? ?? '1080',
      fps: json['fps'] as int? ?? 30,
    );
  }
}
