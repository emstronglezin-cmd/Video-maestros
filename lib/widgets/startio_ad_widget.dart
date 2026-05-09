/**
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 📺 START.IO AD WIDGET - Flutter Web
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * Widget pour afficher les publicités Start.io sur Flutter Web
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */

import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import '../services/ads_service.dart';
import '../config/api_config.dart';

/// Types de publicités Start.io
enum StartIoAdType {
  banner,      // Bannière (320x50 ou 728x90)
  interstitial, // Plein écran
  video,       // Vidéo
}

/// Widget pour afficher une publicité Start.io
class StartIoAdWidget extends StatefulWidget {
  final StartIoAdType adType;
  final double? width;
  final double? height;
  final VoidCallback? onAdLoaded;
  final VoidCallback? onAdFailed;

  const StartIoAdWidget({
    Key? key,
    required this.adType,
    this.width,
    this.height,
    this.onAdLoaded,
    this.onAdFailed,
  }) : super(key: key);

  @override
  State<StartIoAdWidget> createState() => _StartIoAdWidgetState();
}

class _StartIoAdWidgetState extends State<StartIoAdWidget> {
  final AdsService _adsService = AdsService();
  bool _isLoading = true;
  bool _shouldShowAd = false;
  String? _viewId;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAd();
  }

  /// Vérifier si l'utilisateur doit voir des publicités
  Future<void> _checkAndLoadAd() async {
    try {
      final shouldShow = await _adsService.shouldShowAds();
      if (mounted) {
        setState(() {
          _shouldShowAd = shouldShow;
          _isLoading = false;
        });

        if (shouldShow) {
          _registerAdView();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shouldShowAd = false;
        });
        widget.onAdFailed?.call();
      }
    }
  }

  /// Enregistrer la vue de publicité
  void _registerAdView() {
    final viewId = 'startio-ad-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _viewId = viewId;
    });

    // Créer l'élément HTML pour la publicité
    final divElement = html.DivElement()
      ..id = viewId
      ..style.width = '100%'
      ..style.height = '100%';

    // Ajouter le script Start.io
    _injectStartIoScript(divElement);

    // Enregistrer la vue
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => divElement,
    );

    // Tracker l'impression
    _trackImpression();
    widget.onAdLoaded?.call();
  }

  /// Injecter le script Start.io dans l'élément
  void _injectStartIoScript(html.DivElement container) {
    final publisherId = ApiConfig.startIoPublisherId;
    
    // Script Start.io selon le type de publicité
    String scriptContent = '';
    
    switch (widget.adType) {
      case StartIoAdType.banner:
        scriptContent = '''
          (function(s,t,a,r,t,i,o){{
            s[t]||(r=s[t]=function(){{r._.push(arguments)}},
            r._=[],i=a.createElement("script"),
            i.async=1,i.src="//s.ad.startapp.com/inapp",
            o=a.getElementsByTagName("script")[0],o.parentNode.insertBefore(i,o))
          }})(window,"_startapp",document);
          
          _startapp("banner", {{
            appId: "$publisherId",
            size: "medium",
          }});
        ''';
        break;
        
      case StartIoAdType.interstitial:
        scriptContent = '''
          (function(s,t,a,r,t,i,o){{
            s[t]||(r=s[t]=function(){{r._.push(arguments)}},
            r._=[],i=a.createElement("script"),
            i.async=1,i.src="//s.ad.startapp.com/inapp",
            o=a.getElementsByTagName("script")[0],o.parentNode.insertBefore(i,o))
          }})(window,"_startapp",document);
          
          _startapp("interstitial", {{
            appId: "$publisherId"
          }});
        ''';
        break;
        
      case StartIoAdType.video:
        scriptContent = '''
          (function(s,t,a,r,t,i,o){{
            s[t]||(r=s[t]=function(){{r._.push(arguments)}},
            r._=[],i=a.createElement("script"),
            i.async=1,i.src="//s.ad.startapp.com/inapp",
            o=a.getElementsByTagName("script")[0],o.parentNode.insertBefore(i,o))
          }})(window,"_startapp",document);
          
          _startapp("video", {{
            appId: "$publisherId"
          }});
        ''';
        break;
    }

    // Créer et ajouter le script
    final scriptElement = html.ScriptElement()
      ..text = scriptContent;
    
    container.children.add(scriptElement);
  }

  /// Tracker l'impression publicitaire
  Future<void> _trackImpression() async {
    try {
      await _adsService.trackImpression(
        widget.adType.toString(),
        _viewId ?? 'unknown',
      );
    } catch (e) {
      print('Failed to track ad impression: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_shouldShowAd || _viewId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 90,
      color: Colors.grey[100],
      child: HtmlElementView(
        viewType: _viewId!,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Widget de bannière Start.io (simple à utiliser)
class StartIoBanner extends StatelessWidget {
  final double? height;

  const StartIoBanner({
    Key? key,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StartIoAdWidget(
      adType: StartIoAdType.banner,
      height: height ?? 90,
    );
  }
}

/// Afficher une publicité interstitielle Start.io
class StartIoInterstitial {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              const StartIoAdWidget(
                adType: StartIoAdType.interstitial,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
