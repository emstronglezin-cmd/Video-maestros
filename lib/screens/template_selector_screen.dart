import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class TemplateCategory {
  final String id;
  final String name;
  final String icon;
  
  TemplateCategory(this.id, this.name, this.icon);
}

class VideoTemplate {
  final String id;
  final String name;
  final String description;
  final String platform;
  final bool isPremium;
  final int maxDuration;
  final String aspectRatio;
  final String category;
  final bool trending;
  
  VideoTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.platform,
    required this.isPremium,
    required this.maxDuration,
    required this.aspectRatio,
    required this.category,
    required this.trending,
  });
  
  factory VideoTemplate.fromJson(Map<String, dynamic> json) {
    return VideoTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      platform: json['platform'] ?? '',
      isPremium: json['isPremium'] ?? false,
      maxDuration: json['maxDuration'] ?? 60,
      aspectRatio: json['aspectRatio'] ?? '9:16',
      category: json['category'] ?? '',
      trending: json['trending'] ?? false,
    );
  }
}

class TemplateSelectorScreen extends StatefulWidget {
  const TemplateSelectorScreen({Key? key}) : super(key: key);

  @override
  _TemplateSelectorScreenState createState() => _TemplateSelectorScreenState();
}

class _TemplateSelectorScreenState extends State<TemplateSelectorScreen> {
  String selectedCategory = 'all';
  String selectedPlatform = 'all';
  List<VideoTemplate> templates = [];
  bool isLoading = true;

  final List<TemplateCategory> categories = [
    TemplateCategory('all', 'Tous', '🎬'),
    TemplateCategory('viral', 'Viral', '🔥'),
    TemplateCategory('cinematic', 'Cinématique', '🎥'),
    TemplateCategory('fun', 'Fun', '😄'),
    TemplateCategory('professional', 'Pro', '💼'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => isLoading = true);
    
    try {
      // Mock templates - à remplacer par API call
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        templates = [
          VideoTemplate(
            id: 'tiktok-basic-15s',
            name: 'TikTok Basic 15s',
            description: 'Template TikTok basique 15 secondes',
            platform: 'tiktok',
            isPremium: false,
            maxDuration: 15,
            aspectRatio: '9:16',
            category: 'viral',
            trending: true,
          ),
          VideoTemplate(
            id: 'reels-simple-30s',
            name: 'Reels Simple 30s',
            description: 'Template Instagram Reels simple',
            platform: 'reels',
            isPremium: false,
            maxDuration: 30,
            aspectRatio: '9:16',
            category: 'viral',
            trending: true,
          ),
          VideoTemplate(
            id: 'tiktok-viral-pro-60s',
            name: 'TikTok Viral Pro',
            description: 'Template TikTok viral premium',
            platform: 'tiktok',
            isPremium: true,
            maxDuration: 60,
            aspectRatio: '9:16',
            category: 'viral',
            trending: true,
          ),
        ];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<VideoTemplate> get filteredTemplates {
    return templates.where((template) {
      if (selectedCategory != 'all' && template.category != selectedCategory) {
        return false;
      }
      if (selectedPlatform != 'all' && template.platform != selectedPlatform) {
        return false;
      }
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
        title: const Text('📱 Templates Viraux'),
        actions: [
          if (!userIsPremium)
            IconButton(
              icon: const Icon(Icons.star, color: Colors.amber),
              onPressed: () {
                // TODO: Navigate to premium upgrade
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : Column(
              children: [
                // Category filter
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category.id;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(category.icon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(category.name),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedCategory = category.id;
                            });
                          },
                          selectedColor: Colors.purple,
                          backgroundColor: Colors.grey[800],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Platform filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Plateforme:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('Toutes')),
                            ButtonSegment(value: 'tiktok', label: Text('TikTok')),
                            ButtonSegment(value: 'reels', label: Text('Reels')),
                            ButtonSegment(value: 'shorts', label: Text('Shorts')),
                          ],
                          selected: {selectedPlatform},
                          onSelectionChanged: (Set<String> selection) {
                            setState(() {
                              selectedPlatform = selection.first;
                            });
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.purple
                                  : Colors.grey[800]!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.grey),

                // Templates grid
                Expanded(
                  child: filteredTemplates.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun template disponible',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = filteredTemplates[index];
                            final canUse = !template.isPremium || userIsPremium;

                            return _buildTemplateCard(template, canUse);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTemplateCard(VideoTemplate template, bool canUse) {
    return GestureDetector(
      onTap: () {
        if (canUse) {
          _selectTemplate(template);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template Premium - Abonnement requis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: template.trending
              ? Border.all(color: Colors.amber, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail placeholder
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      template.aspectRatio,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
                              template.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (template.isPremium)
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${template.maxDuration}s max',
                        style: const TextStyle(color: Colors.purple, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Badges
            if (template.trending)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🔥 TENDANCE',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Lock overlay for premium templates
            if (template.isPremium && !canUse)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock, color: Colors.amber, size: 40),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectTemplate(VideoTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(template.name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildTemplateInfo('Format', template.aspectRatio),
            _buildTemplateInfo('Durée max', '${template.maxDuration}s'),
            _buildTemplateInfo('Plateforme', template.platform.toUpperCase()),
            _buildTemplateInfo('Catégorie', template.category),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, template);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Utiliser ce template'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
