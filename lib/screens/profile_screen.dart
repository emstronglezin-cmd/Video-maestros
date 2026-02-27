import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// Écran de profil utilisateur
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final stats = provider.userStats;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar et ID
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(
                            stats?.isPremium ?? false
                                ? Icons.workspace_premium
                                : Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'User ID: ${provider.userId.substring(0, 12)}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Statut d'abonnement
                  if (stats != null) ...[
                    Card(
                      color: stats.isPremium ? Colors.amber[50] : Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  stats.isPremium
                                      ? Icons.workspace_premium
                                      : Icons.account_circle,
                                  color: stats.isPremium
                                      ? Colors.amber[700]
                                      : Colors.blue[700],
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  stats.isPremium ? 'Premium' : 'Gratuit',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildStatRow(
                              Icons.today,
                              'Exports aujourd\'hui',
                              '${stats.todayExports}',
                            ),
                            const Divider(height: 24),
                            _buildStatRow(
                              Icons.upcoming,
                              'Exports restants',
                              stats.remainingExportsText,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Limites
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vos limites',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLimitRow(
                              Icons.high_quality,
                              'Résolution maximale',
                              stats.limits.maxResolutionText,
                            ),
                            const Divider(height: 24),
                            _buildLimitRow(
                              Icons.calendar_today,
                              'Exports quotidiens',
                              stats.limits.dailyExportsText,
                            ),
                            const Divider(height: 24),
                            _buildLimitRow(
                              Icons.water_drop,
                              'Filigrane',
                              stats.limits.watermark ? 'Oui' : 'Non',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bouton upgrade
                    if (stats.isFree)
                      FilledButton.icon(
                        onPressed: () {
                          _showUpgradeDialog(context);
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text('Passer à Premium'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                  ] else ...[
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Refresh button
                  OutlinedButton.icon(
                    onPressed: () => provider.loadUserStats(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser les stats'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLimitRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('Passer à Premium'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avantages Premium:'),
            SizedBox(height: 8),
            Text('• Exports illimités'),
            Text('• Résolution 4K'),
            Text('• Sans filigrane'),
            Text('• Support prioritaire'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fonctionnalité à venir !'),
                ),
              );
            },
            child: const Text('S\'abonner'),
          ),
        ],
      ),
    );
  }
}
