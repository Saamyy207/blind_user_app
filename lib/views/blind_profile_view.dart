import 'package:blind_user_app/views/blinduser_homepage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'ObjectDetectionScreen.dart';
import 'SpeechScreen .dart';

class BlindProfileView extends StatefulWidget {
  final String userId;
  const BlindProfileView({super.key, required this.userId});

  @override
  State<BlindProfileView> createState() => _BlindProfileViewState();
}

class _BlindProfileViewState extends State<BlindProfileView> {
  final SupabaseClient supabase = Supabase.instance.client;
  final FlutterTts flutterTts = FlutterTts();
  String userName = "";

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _initTts();
    Future.delayed(const Duration(milliseconds: 500), () {
      speak("Home page. Three options available: AI Agent,  Map Guidance, Call");
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askLocationSharingPermission();
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
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
      } else if (label == "Object Detection") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ObjectDetectionScreen()),
        );
      } else if (label == "Call") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BlindUserHomePage()),
        );
      }
    });
  }

  Widget buildButton(String label, IconData icon, Color color, BuildContext context) {
    return Semantics(
      label: "Button $label",
      hint: "Tap to access $label",
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _handleButtonTap(label, context),
        onDoubleTap: () => _handleButtonTap(label, context),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 50,
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
                const SizedBox(width: 18),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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

  Future<void> _askLocationSharingPermission() async {
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Share your location"),
        content: const Text("Do you want to share your location with your assistant?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (consent == true) {
      await _checkPermission();
      _startTracking();
    }
  }

  Future<void> _fetchUserInfo() async {
    final response = await supabase
        .from('users')
        .select('nom')
        .eq('id', widget.userId)
        .single();

    setState(() {
      userName = response['nom'];
    });
  }

  Future<void> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _startTracking() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      await supabase.from('positions').insert({
        'user_id': widget.userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $userName"),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Semantics(
                label: "Visual Navigation",
                header: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 40,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Visual Navigation',
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
              const SizedBox(height: 15),
              Semantics(
                label: "Instructions: Tap one of the buttons below",
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Tap one of the buttons below",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              buildButton("AI Agent", Icons.smart_toy, Colors.deepPurple, context),
              buildButton("Object Detection", Icons.visibility, Colors.teal, context),
              buildButton("Call", Icons.phone, Colors.indigo, context),
              
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: "Repeat options",
                child: GestureDetector(
                  onTap: () {
                    speak("Available options: AI Agent, Object Detection, Phone call");
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
