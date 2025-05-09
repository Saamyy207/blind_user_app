import 'package:blind_user_app/views/blinduser_homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
// Importez la page AIAgentScreen
import 'ObjectDetectionScreen.dart';
import 'SpeechScreen .dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    Future.delayed(const Duration(milliseconds: 500), () {
      speak("Page d'accueil. Trois options disponibles: AI Agent, Détection des objets, Map Guidage, Appel");
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("fr-FR");
    await flutterTts.setPitch(1);
    await flutterTts.setSpeechRate(0.9);
  }

  Future<void> speak(String text) async {
    await flutterTts.speak(text);
  }

  void _handleButtonTap(String label, BuildContext context) {
    speak(label);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (label == "AI Agent") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AIAgentScreen()),
        );
      } else if (label == "Détection des objets") {
        // Navigation vers l'écran de détection d'objets
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ObjectDetectionScreen()),
        );
      }
      else if (label == "Appel") {

        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>  BlindUserHomePage()),
        );
      }else if (label == "Map Guidage") {
        speak("Le guidage par carte n'est pas encore disponible");
      }
    });
  }

  Widget buildButton(String label, IconData icon, Color color, BuildContext context) {
    return Semantics(
      label: "Bouton $label",
      hint: "Appuyez pour accéder à $label",
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _handleButtonTap(label, context),
        onDoubleTap: () => _handleButtonTap(label, context),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 38),
                const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              ],
            ),

          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF003049), Color(0xFF8ECAE6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Semantics(
                label: "Navigation Visuelle",
                header: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 60,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Navigation Visuelle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 2),
                              blurRadius: 4,
                              color: Color.fromRGBO(0, 0, 0, 0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                label: "Instructions: Appuyez sur l'un des boutons ci-dessous",
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Appuyez sur l'un des boutons ci-dessous",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              buildButton("AI Agent", Icons.smart_toy, Colors.deepPurple, context),
              buildButton("Détection des objets", Icons.visibility, Colors.teal, context),
              buildButton("Appel", Icons.phone, Colors.indigo, context),
              buildButton("Map Guidage", Icons.map, Colors.indigo, context),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: "Répéter les options",
                child: GestureDetector(
                  onTap: () {
                    speak("Options disponibles: AI Agent, Détection des objets, Map Guidage");
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
