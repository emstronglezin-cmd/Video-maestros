import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/payment.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran de paiement GeniusPay - UI moderne startup-style
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedPlan = 'monthly';
  bool _isProcessing = false;
  Payment? _currentPayment;

  final Map<String, Map<String, dynamic>> _plans = {
    'monthly': {
      'name': 'Premium Mensuel',
      'price': 2000,
      'currency': 'XOF',
      'duration': '30 jours',
      'features': [
        'Exports illimités',
        'Résolution 4K',
        'Sans watermark',
        'Support prioritaire',
        'Tous les templates',
        'Effets premium',
      ],
      'popular': false,
    },
    'yearly': {
      'name': 'Premium Annuel',
      'price': 20000,
      'currency': 'XOF',
      'duration': '365 jours',
      'features': [
        'Exports illimités',
        'Résolution 4K',
        'Sans watermark',
        'Support prioritaire',
        'Tous les templates',
        'Effets premium',
        '2 mois gratuits',
        'Accès anticipé',
      ],
      'popular': true,
      'savings': '17%',
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final userId = provider.userId;

    if (userId == null || userId.isEmpty) {
      _showError('Veuillez vous connecter pour continuer');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final planData = _plans[_selectedPlan]!;
      final payment = await provider.apiService.createPayment(
        userId: userId,
        amount: planData['price'].toDouble(),
        currency: planData['currency'],
        plan: _selectedPlan,
      );

      setState(() {
        _currentPayment = payment;
      });

      // Ouvrir l'URL de paiement GeniusPay
      if (payment.paymentUrl != null) {
        final uri = Uri.parse(payment.paymentUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Démarrer la vérification du statut
          _startPaymentVerification(payment.id);
        } else {
          _showError('Impossible d\'ouvrir le lien de paiement');
        }
      }
    } catch (e) {
      _showError('Erreur lors de la création du paiement: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _startPaymentVerification(String paymentId) {
    // Vérifier le statut toutes les 5 secondes
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      try {
        final provider = Provider.of<AppProvider>(context, listen: false);
        final payment = await provider.apiService.getPaymentStatus(paymentId);

        if (payment.status == 'completed') {
          // Paiement réussi
          if (mounted) {
            _showSuccess();
          }
        } else if (payment.status == 'failed') {
          // Paiement échoué
          if (mounted) {
            _showError('Le paiement a échoué');
          }
        } else {
          // Continuer la vérification
          if (mounted) {
            _startPaymentVerification(paymentId);
          }
        }
      } catch (e) {
        // Continuer la vérification en cas d'erreur
        if (mounted) {
          _startPaymentVerification(paymentId);
        }
      }
    });
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 20),
            const Text(
              'Paiement réussi !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Votre compte Premium est maintenant actif',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continuer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // Header
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  floating: true,
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Titre
                      const Text(
                        'Passez à Premium',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Débloquez toutes les fonctionnalités',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Plans
                      ..._plans.entries.map((entry) {
                        final planId = entry.key;
                        final plan = entry.value;
                        final isSelected = _selectedPlan == planId;
                        final isPopular = plan['popular'] == true;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedPlan = planId),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.grey.shade800,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF667EEA).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          plan['name'],
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${plan['price']}',
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Text(
                                            plan['currency'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      plan['duration'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    if (plan['savings'] != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade700,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Économisez ${plan['savings']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    ...List.generate(
                                      (plan['features'] as List).length,
                                      (index) {
                                        final feature = plan['features'][index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle_outline,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.grey.shade600,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                feature,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.grey.shade400,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (isPopular)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '⭐ POPULAIRE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Bouton de paiement
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            disabledBackgroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Payer maintenant',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Note de sécurité
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                'Paiement 100% sécurisé avec GeniusPay',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
