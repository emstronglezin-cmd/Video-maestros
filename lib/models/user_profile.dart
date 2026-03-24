class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPremium;
  final int videosCreated;
  final int storageUsed;

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
    required this.isPremium,
    required this.videosCreated,
    required this.storageUsed,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPremium: json['isPremium'] as bool? ?? false,
      videosCreated: json['videosCreated'] as int? ?? 0,
      storageUsed: json['storageUsed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPremium': isPremium,
      'videosCreated': videosCreated,
      'storageUsed': storageUsed,
    };
  }
}
