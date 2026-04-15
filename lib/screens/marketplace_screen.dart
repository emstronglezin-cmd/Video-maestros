import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

enum EffectType { transition, overlay, sound, filter, sticker }
enum EffectCategory { viral, cinematic, corporate, fun, music, nature, retro }

class Effect {
  final String id;
  final String name;
  final String description;
  final EffectType type;
  final EffectCategory category;
  final bool isPremium;
  final double price;
  final int downloads;
  final double rating;
  
  Effect({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    required this.isPremium,
    required this.price,
    required this.downloads,
    required this.rating,
  });
}

class EffectPack {
  final String id;
  final String name;
  final String description;
  final List<Effect> effects;
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
  
  final List<Effect> mockEffects = [
    Effect(
      id: 'transition-fade-basic',
      name: 'Fade Basique',
      description: 'Transition fade simple et élégante',
      type: EffectType.transition,
      category: EffectCategory.viral,
      isPremium: false,
      price: 0,
      downloads: 1500,
      rating: 4.5,
    ),
    Effect(
      id: 'transition-zoom-burst',
      name: 'Zoom Burst',
      description: 'Transition zoom explosif style viral',
      type: EffectType.transition,
      category: EffectCategory.viral,
      isPremium: true,
      price: 1.99,
      downloads: 850,
      rating: 4.8,
    ),
    Effect(
      id: 'overlay-film-grain-4k',
      name: 'Film Grain 4K',
      description: 'Grain de film professionnel 4K',
      type: EffectType.overlay,
      category: EffectCategory.cinematic,
      isPremium: true,
      price: 3.99,
      downloads: 650,
      rating: 4.9,
    ),
    Effect(
      id: 'sound-whoosh-basic',
      name: 'Whoosh Basique',
      description: 'Son whoosh pour transitions',
      type: EffectType.sound,
      category: EffectCategory.viral,
      isPremium: false,
      price: 0,
      downloads: 3200,
      rating: 4.4,
    ),
  ];

  final List<EffectPack> mockPacks = [
    EffectPack(
      id: 'pack-viral-starter',
      name: 'Viral Starter Pack',
      description: 'Pack complet pour débuter sur TikTok/Reels',
      effects: [],
      price: 4.99,
      discount: 40,
      downloads: 420,
      rating: 4.8,
    ),
    EffectPack(
      id: 'pack-cinematic-pro',
      name: 'Cinematic Pro Pack',
      description: 'Pack professionnel pour vidéos cinématiques',
      effects: [],
      price: 6.99,
      discount: 35,
      downloads: 310,
      rating: 4.9,
    ),
  ];

  Set<String> ownedEffects = {};
  Set<String> ownedPacks = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Effect> get filteredEffects {
    return mockEffects.where((effect) {
      if (selectedType != null && effect.type != selectedType) return false;
      if (selectedCategory != null && effect.category != selectedCategory) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userIsPremium = false; // All features are free (Open Source)

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('🛒 Marketplace'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.purple,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Effets'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'Packs'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () => _showMyLibrary(),
            tooltip: 'Ma bibliothèque',
          ),
        ],
      ),
      body: TabBarView(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('Tous', selectedType == null, () {
                    setState(() => selectedType = null);
                  }),
                  ...EffectType.values.map((type) => _buildFilterChip(
                    _getTypeName(type),
                    selectedType == type,
                    () => setState(() => selectedType = type),
                  )),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.grey, height: 1),
        
        // Effects grid
        Expanded(
          child: filteredEffects.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun effet disponible',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: filteredEffects.length,
                  itemBuilder: (context, index) {
                    final effect = filteredEffects[index];
                    final isOwned = ownedEffects.contains(effect.id);
                    final canUse = !effect.isPremium || userIsPremium || isOwned;
                    
                    return _buildEffectCard(effect, canUse, isOwned);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPacksTab(bool userIsPremium) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockPacks.length,
      itemBuilder: (context, index) {
        final pack = mockPacks[index];
        final isOwned = ownedPacks.contains(pack.id);
        
        return _buildPackCard(pack, userIsPremium, isOwned);
      },
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.purple,
      backgroundColor: Colors.grey[800],
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey[400],
        fontSize: 12,
      ),
    );
  }

  Widget _buildEffectCard(Effect effect, bool canUse, bool isOwned) {
    return GestureDetector(
      onTap: () => _showEffectDetails(effect, canUse, isOwned),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: isOwned ? Border.all(color: Colors.green, width: 2) : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Icon(
                      _getTypeIcon(effect.type),
                      size: 40,
                      color: Colors.purple,
                    ),
                  ),
                ),
                
                // Info
                Expanded(
                  child: Padding(
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
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (effect.isPremium && !isOwned)
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          effect.description,
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.download, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              '${effect.downloads}',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${effect.rating}',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (!isOwned)
                          Text(
                            effect.price == 0 ? 'GRATUIT' : '${effect.price.toStringAsFixed(2)}€',
                            style: TextStyle(
                              color: effect.price == 0 ? Colors.green : Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        else
                          const Text(
                            '✓ POSSÉDÉ',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Lock overlay
            if (!canUse && !isOwned)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock, color: Colors.amber, size: 32),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackCard(EffectPack pack, bool userIsPremium, bool isOwned) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showPackDetails(pack, userIsPremium, isOwned),
        borderRadius: BorderRadius.circular(12),
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
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag, color: Colors.purple, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pack.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isOwned)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '✓ POSSÉDÉ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pack.description,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${pack.discount}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pack.price.toStringAsFixed(2)}€',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.download, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    '${pack.downloads}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${pack.rating}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEffectDetails(Effect effect, bool canUse, bool isOwned) {
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
            _buildDetailRow('Type', _getTypeName(effect.type)),
            _buildDetailRow('Catégorie', _getCategoryName(effect.category)),
            _buildDetailRow('Téléchargements', '${effect.downloads}'),
            _buildDetailRow('Note', '${effect.rating} ⭐'),
            if (!isOwned)
              _buildDetailRow('Prix', effect.price == 0 ? 'GRATUIT' : '${effect.price.toStringAsFixed(2)}€'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
          if (!isOwned && canUse)
            ElevatedButton(
              onPressed: () {
                _purchaseEffect(effect);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text(effect.price == 0 ? 'Télécharger' : 'Acheter'),
            ),
        ],
      ),
    );
  }

  void _showPackDetails(EffectPack pack, bool userIsPremium, bool isOwned) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(pack.name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pack.description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            _buildDetailRow('Prix', '${pack.price.toStringAsFixed(2)}€'),
            _buildDetailRow('Réduction', '-${pack.discount}%'),
            _buildDetailRow('Téléchargements', '${pack.downloads}'),
            _buildDetailRow('Note', '${pack.rating} ⭐'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
          if (!isOwned)
            ElevatedButton(
              onPressed: () {
                _purchasePack(pack);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Acheter le pack'),
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
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _purchaseEffect(Effect effect) {
    setState(() {
      ownedEffects.add(effect.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${effect.name} ajouté à votre bibliothèque'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _purchasePack(EffectPack pack) {
    setState(() {
      ownedPacks.add(pack.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${pack.name} ajouté à votre bibliothèque'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showMyLibrary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('📚 Ma Bibliothèque', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effets possédés: ${ownedEffects.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              'Packs possédés: ${ownedPacks.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (ownedEffects.isEmpty && ownedPacks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Votre bibliothèque est vide.\nAchetez des effets pour commencer!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  String _getTypeName(EffectType type) {
    switch (type) {
      case EffectType.transition:
        return 'Transitions';
      case EffectType.overlay:
        return 'Overlays';
      case EffectType.sound:
        return 'Sons';
      case EffectType.filter:
        return 'Filtres';
      case EffectType.sticker:
        return 'Stickers';
    }
  }

  String _getCategoryName(EffectCategory category) {
    switch (category) {
      case EffectCategory.viral:
        return 'Viral';
      case EffectCategory.cinematic:
        return 'Cinématique';
      case EffectCategory.corporate:
        return 'Corporate';
      case EffectCategory.fun:
        return 'Fun';
      case EffectCategory.music:
        return 'Musique';
      case EffectCategory.nature:
        return 'Nature';
      case EffectCategory.retro:
        return 'Retro';
    }
  }

  IconData _getTypeIcon(EffectType type) {
    switch (type) {
      case EffectType.transition:
        return Icons.arrow_forward;
      case EffectType.overlay:
        return Icons.layers;
      case EffectType.sound:
        return Icons.volume_up;
      case EffectType.filter:
        return Icons.filter_vintage;
      case EffectType.sticker:
        return Icons.emoji_emotions;
    }
  }
}
