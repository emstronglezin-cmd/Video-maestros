/// Modèle de paiement GeniusPay
class Payment {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final String status;
  final String? paymentUrl;
  final DateTime createdAt;
  final DateTime? completedAt;

  Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentUrl,
    required this.createdAt,
    this.completedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      paymentUrl: json['paymentUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paymentUrl': paymentUrl,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

/// Modèle d'abonnement utilisateur
class UserSubscription {
  final String userId;
  final String plan;
  final String status;
  final DateTime? expiresAt;
  final bool isPremium;

  UserSubscription({
    required this.userId,
    required this.plan,
    required this.status,
    this.expiresAt,
    required this.isPremium,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['userId'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'plan': plan,
      'status': status,
      'expiresAt': expiresAt?.toIso8601String(),
      'isPremium': isPremium,
    };
  }
}
