import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- POINT D'ENTRÉE DE LA FENÊTRE FLOTTANTE ---
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

// --- POINT D'ENTRÉE DE L'APP PRINCIPALE ---
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainApp(),
  ));
}

// --- ÉCRAN PRINCIPAL (Gestion du script) ---
class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final TextEditingController _scriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScript();
  }

  Future<void> _loadScript() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scriptController.text = prefs.getString('saved_script') ?? 'Tapez votre script ici...';
    });
  }

  Future<void> _saveScript() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_script', _scriptController.text);
  }

  Future<void> _launchOverlay() async {
    await _saveScript();
    
    // Vérification de la permission Android "Afficher par-dessus"
    bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }
    
    // Partage du texte avec la bulle flottante
    await FlutterOverlayWindow.shareData(_scriptController.text);
    
    // Lancement de la bulle
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Téléprompteur",
      overlayContent: "En attente...",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 600,
      width: WindowSize.matchParent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text('Bibliothèque de Scripts'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _scriptController,
                maxLines: null,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF222222),
                  hintText: "Votre script...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => _saveScript(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _launchOverlay,
                child: const Text('LANCER LE TÉLÉPROMPTEUR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- WIDGET FLOTTANT (L'Overlay) ---
class OverlayWidget extends StatefulWidget {
  const OverlayWidget({Key? key}) : super(key: key);

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String scriptText = "Chargement...";
  bool isPlaying = false;
  double scrollSpeed = 1.0; // Vitesse de base
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is String) {
        setState(() { scriptText = event; });
      }
    });
  }

  void _togglePlay() {
    setState(() { isPlaying = !isPlaying; });
    if (isPlaying) {
      _startScrolling();
    } else {
      _scrollTimer?.cancel();
    }
  }

  void _startScrolling() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        
        if (currentScroll < maxScroll) {
          _scrollController.jumpTo(currentScroll + scrollSpeed);
        } else {
          _togglePlay(); // Stop à la fin
        }
      }
    });
  }

  void _closeOverlay() {
    _scrollTimer?.cancel();
    FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65), // Transparence pour voir la caméra
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueAccent, width: 2),
        ),
        child: Column(
          children: [
            // Zone de texte déroulante
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 50), // Espace avant de démarrer
                      Text(
                        scriptText,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 200), // Espace pour la fin
                    ],
                  ),
                ),
              ),
            ),
            // Barre de contrôles compacte
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: _closeOverlay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.fast_rewind, color: Colors.white),
                    onPressed: () {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo((_scrollController.offset - 150).clamp(0, double.infinity));
                      }
                    },
                  ),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: isPlaying ? Colors.orange : Colors.green,
                    onPressed: _togglePlay,
                    child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    icon: const Icon(Icons.speed, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        scrollSpeed = scrollSpeed >= 3.0 ? 0.5 : scrollSpeed + 0.5;
                      });
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
