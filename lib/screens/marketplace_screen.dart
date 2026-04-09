import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

enum EffectType { transition, overlay, sound, filter, sticker }
enum EffectCategory { viral, cinematic, fun, music, nature }

class MarketEffect {
  final String id;
  final String name;
  final String description;
  final EffectType type;
  final EffectCategory category;
  final bool isPremium;
  final double price;
  final int downloads;
  final double rating;
  final String previewUrl;
  
  MarketEffect({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    required this.isPremium,
    required this.price,
    required this.downloads,
    required this.rating,
    required this.previewUrl,
  });
}

class EffectPack {
  final String id;
  final String name;
  final String description;
  final List<MarketEffect> effects;
  final double price;
  final int discount;
  final int downloads;
  final double rating;
  
  EffectPack({
    required this.id,
    required this.name,
    required this.description,
    required this.effects,
    required this.price,
    required this.discount,
    required this.downloads,
    required this.rating,
  });
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  _MarketplaceScreenState createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EffectType? selectedType;
  EffectCategory? selectedCategory;
  bool showOnlyFree = false;
  
  List<MarketEffect> effects = [];
  List<EffectPack> packs = [];
  Set<String> ownedEffects = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMarketplace();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketplace() async {
    setState(() => isLoading = true);
    
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      effects = [
        MarketEffect(
          id: 'transition-fade-basic',
          name: 'Fade Basique',
          description: 'Transition fade simple et élégante',
          type: EffectType.transition,
          category: EffectCategory.viral,
          isPremium: false,
          price: 0,
          downloads: 1500,
          rating: 4.5,
          previewUrl: '',
        ),
        MarketEffect(
          id: 'transition-zoom-burst',
          name: 'Zoom Burst',
          description: 'Transition zoom explosif viral',
          type: EffectType.transition,
          category: EffectCategory.viral,
          isPremium: true,
          price: 1.99,
          downloads: 850,
          rating: 4.8,
          previewUrl: '',
        ),
        MarketEffect(
          id: 'overlay-light-leaks',
          name: 'Light Leaks',
          description: 'Overlay de fuites de lumière',
          type: EffectType.overlay,
          category: EffectCategory.cinematic,
          isPremium: false,
          price: 0,
          downloads: 2100,
          rating: 4.6,
          previewUrl: '',
        ),
        MarketEffect(
          id: 'overlay-film-grain-4k',
          name: 'Film Grain 4K',
          description: 'Grain de film professionnel',
          type: EffectType.overlay,
          category: EffectCategory.cinematic,
          isPremium: true,
          price: 3.99,
          downloads: 650,
          rating: 4.9,
          previewUrl: '',
        ),
        MarketEffect(
          id: 'sound-whoosh',
          name: 'Whoosh',
          description: 'Son whoosh pour transitions',
          type: EffectType.sound,
          category: EffectCategory.viral,
          isPremium: false,
          price: 0,
          downloads: 3200,
          rating: 4.4,
          previewUrl: '',
        ),
        MarketEffect(
          id: 'sound-cinematic-hit',
          name: 'Cinematic Hit',
          description: 'Impact cinématique puissant',
          type: EffectType.sound,
          category: EffectCategory.cinematic,
          isPremium: true,
          price: 1.49,
          downloads: 1100,
          rating: 4.7,
          previewUrl: '',
        ),
      ];
      
      packs = [
        EffectPack(
          id: 'pack-viral-starter',
          name: 'Viral Starter Pack',
          description: 'Pack complet pour TikTok/Reels',
          effects: effects.where((e) => ['transition-zoom-burst', 'sound-whoosh'].contains(e.id)).toList(),
          price: 4.99,
          discount: 40,
          downloads: 420,
          rating: 4.8,
        ),
        EffectPack(
          id: 'pack-cinematic-pro',
          name: 'Cinematic Pro Pack',
          description: 'Pack professionnel cinématique',
          effects: effects.where((e) => ['overlay-film-grain-4k', 'sound-cinematic-hit'].contains(e.id)).toList(),
          price: 6.99,
          discount: 35,
          downloads: 310,
          rating: 4.9,
        ),
      ];
      
      isLoading = false;
    });
  }

  List<MarketEffect> get filteredEffects {
    return effects.where((effect) {
      if (showOnlyFree && effect.price > 0) return false;
      if (selectedType != null && effect.type != selectedType) return false;
      if (selectedCategory != null && effect.category != selectedCategory) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final userIsPremium = appProvider.userProfile?.isPremium ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('🛒 Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () => _showMyLibrary(),
            tooltip: 'Ma bibliothèque',
          ),
          if (!userIsPremium)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.star, color: Colors.amber, size: 20),
                label: const Text('Premium', style: TextStyle(color: Colors.amber)),
                onPressed: () {
                  // TODO: Navigate to premium upgrade
                },
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          tabs: const [
            Tab(text: '✨ Effets', icon: Icon(Icons.auto_awesome)),
            Tab(text: '📦 Packs', icon: Icon(Icons.inventory_2)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEffectsTab(userIsPremium),
                _buildPacksTab(userIsPremium),
              ],
            ),
    );
  }

  Widget _buildEffectsTab(bool userIsPremium) {
    return Column(
      children: [
        // Filters
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Type filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tous', selectedType == null, () {
                      setState(() => selectedType = null);
                    }),
                    const SizedBox(width: 8),
                    ..._buildTypeFilters(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Free filter
              Row(
                children: [
                  Checkbox(
                    value: showOnlyFree,
                    onChanged: (val) => setState(() => showOnlyFree = val ?? false),
                    activeColor: Colors.purple,
                  ),
                  const Text('Gratuit uniquement', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),

        // Effects grid
        Expanded(
          child: filteredEffects.isEmpty
              ? const Center(child: Text('Aucun effet disponible', style: TextStyle(color: Colors.white70)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: filteredEffects.length,
                  itemBuilder: (context, index) {
                    return _buildEffectCard(filteredEffects[index], userIsPremium);
                  },
                ),
        ),
      ],
    );
  }

  List<Widget> _buildTypeFilters() {
    return EffectType.values.map((type) {
      final isSelected = selectedType == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _buildFilterChip(
          _getTypeLabel(type),
          isSelected,
          () => setState(() => selectedType = isSelected ? null : type),
        ),
      );
    }).toList();
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.purple : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEffectCard(MarketEffect effect, bool userIsPremium) {
    final isOwned = ownedEffects.contains(effect.id);
    final canUse = effect.price == 0 || isOwned || userIsPremium;

    return GestureDetector(
      onTap: () => _showEffectDetails(effect, canUse),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  _getTypeIcon(effect.type),
                  size: 48,
                  color: Colors.purple,
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          effect.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwned)
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    effect.price > 0 ? '${effect.price.toStringAsFixed(2)}€' : 'GRATUIT',
                    style: TextStyle(
                      color: effect.price > 0 ? Colors.amber : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        effect.rating.toString(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${effect.downloads}+',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacksTab(bool userIsPremium) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: packs.length,
      itemBuilder: (context, index) {
        return _buildPackCard(packs[index], userIsPremium);
      },
    );
  }

  Widget _buildPackCard(EffectPack pack, bool userIsPremium) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2, color: Colors.purple, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pack.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pack.effects.map((effect) {
                return Chip(
                  label: Text(effect.name, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.purple.withOpacity(0.3),
                  labelStyle: const TextStyle(color: Colors.white),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pack.price.toStringAsFixed(2)}€',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      '${pack.discount}% de réduction',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _purchasePack(pack),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Acheter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEffectDetails(MarketEffect effect, bool canUse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(effect.name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(effect.description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            _buildDetailRow('Type', _getTypeLabel(effect.type)),
            _buildDetailRow('Catégorie', _getCategoryLabel(effect.category)),
            _buildDetailRow('Prix', effect.price > 0 ? '${effect.price}€' : 'Gratuit'),
            _buildDetailRow('Note', '${effect.rating} ⭐'),
            _buildDetailRow('Téléchargements', '${effect.downloads}+'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
          if (effect.price > 0 && canUse)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _purchaseEffect(effect);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text('Acheter ${effect.price}€'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _purchaseEffect(MarketEffect effect) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Confirmer l\'achat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Acheter "${effect.name}" pour ${effect.price}€?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => ownedEffects.add(effect.id));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${effect.name} acheté avec succès!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _purchasePack(EffectPack pack) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Confirmer l\'achat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Acheter "${pack.name}" pour ${pack.price}€?\n\nContient ${pack.effects.length} effets.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (var effect in pack.effects) {
                  ownedEffects.add(effect.id);
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${pack.name} acheté! ${pack.effects.length} effets débloqués.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showMyLibrary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('📚 Ma Bibliothèque', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ownedEffects.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun effet acheté',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: effects
                      .where((e) => ownedEffects.contains(e.id))
                      .map((effect) => ListTile(
                            leading: Icon(_getTypeIcon(effect.type), color: Colors.purple),
                            title: Text(effect.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(_getTypeLabel(effect.type), style: const TextStyle(color: Colors.white70)),
                            trailing: const Icon(Icons.check_circle, color: Colors.green),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(EffectType type) {
    switch (type) {
      case EffectType.transition: return 'Transition';
      case EffectType.overlay: return 'Overlay';
      case EffectType.sound: return 'Son';
      case EffectType.filter: return 'Filtre';
      case EffectType.sticker: return 'Sticker';
    }
  }

  IconData _getTypeIcon(EffectType type) {
    switch (type) {
      case EffectType.transition: return Icons.swap_horiz;
      case EffectType.overlay: return Icons.layers;
      case EffectType.sound: return Icons.music_note;
      case EffectType.filter: return Icons.filter;
      case EffectType.sticker: return Icons.emoji_emotions;
    }
  }

  String _getCategoryLabel(EffectCategory category) {
    switch (category) {
      case EffectCategory.viral: return 'Viral';
      case EffectCategory.cinematic: return 'Cinématique';
      case EffectCategory.fun: return 'Fun';
      case EffectCategory.music: return 'Musique';
      case EffectCategory.nature: return 'Nature';
    }
  }
}
