/// Statistiques utilisateur
class UserStats {
  final String tier;
  final int todayExports;
  final dynamic remainingExports;
  final UserLimits limits;

  UserStats({
    required this.tier,
    required this.todayExports,
    required this.remainingExports,
    required this.limits,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      tier: json['tier'] as String,
      todayExports: json['todayExports'] as int,
      remainingExports: json['remainingExports'],
      limits: UserLimits.fromJson(json['limits'] as Map<String, dynamic>),
    );
  }

  bool get isPremium => tier == 'premium';
  bool get isFree => tier == 'free';

  String get remainingExportsText {
    if (remainingExports is String) return remainingExports as String;
    return remainingExports.toString();
  }
}

/// Limites utilisateur
class UserLimits {
  final int dailyExports;
  final int maxResolution;
  final int maxDuration;
  final bool watermark;

  UserLimits({
    required this.dailyExports,
    required this.maxResolution,
    required this.maxDuration,
    required this.watermark,
  });

  factory UserLimits.fromJson(Map<String, dynamic> json) {
    return UserLimits(
      dailyExports: json['dailyExports'] as int,
      maxResolution: json['maxResolution'] as int,
      maxDuration: json['maxDuration'] as int,
      watermark: json['watermark'] as bool,
    );
  }

  String get maxResolutionText {
    if (maxResolution >= 2160) return '4K (2160p)';
    if (maxResolution >= 1080) return 'Full HD (1080p)';
    return 'HD (720p)';
  }

  String get dailyExportsText {
    if (dailyExports == -1) return 'Illimité';
    return '$dailyExports par jour';
  }
}
