import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({Key? key}) : super(key: key);

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> with WidgetsBindingObserver {
  late CameraController _controller;
  late FlutterTts flutterTts;
  bool isDetecting = false;
  bool isStreaming = false;
  String serverUrl =
      'https://ff92-196-116-184-148.ngrok-free.app/'; // À changer avec votre URL ngrok

  // Pour le flux vidéo
  Uint8List? processedImageBytes;
  bool _isControllerInitialized = false;
  String detectedObjectsText = "";
  String statusText = "En attente...";

  // Pour le débogage et les statistiques
  int _successfulRequests = 0;
  int _failedRequests = 0;
  double _averageResponseTime = 0;
  bool _serverConnected = false;

  // Pour éviter d'annoncer les mêmes objets continuellement
  Set<String> _lastAnnouncedObjects = {};
  DateTime _lastAnnouncementTime = DateTime.now();

  // Paramètres de détection
  int _frameInterval = 500;
  DateTime _lastFrameTime = DateTime.now();

  // Pour le mode continu
  CameraImage? _currentCameraImage;
  Timer? _processingTimer;

  // Rectangles de détection
  List<Map<String, dynamic>> _detectionBoxes = [];

  // Nouvelle variable pour les caméras disponibles
  List<CameraDescription>? cameras;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _setupPermissions();
    await _setupCamera();
    _initializeTTS();
    _testServerConnection();

    // Instructions vocales initiales après quelques secondes
    Future.delayed(const Duration(milliseconds: 1500), () {
      _speakInstructions();
    });
  }

  Future<void> _setupPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();
  }

  Future<void> _setupCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        setState(() {
          statusText = "Aucune caméra disponible";
        });
        await flutterTts.speak("Aucune caméra n'est disponible sur votre appareil");
        return;
      }

      await _initializeCamera(cameras!.first);
    } catch (e) {
      setState(() {
        statusText = "Erreur lors de l'accès aux caméras: $e";
      });
      await flutterTts.speak("Une erreur s'est produite lors de l'accès à la caméra");
    }
  }

  void _speakInstructions() async {
    await flutterTts.speak(
        "Écran de détection d'objets. Appuyez au milieu de l'écran pour démarrer ou arrêter la détection. "
            "Appuyez en haut à droite pour tester la connexion au serveur. "
            "Appuyez deux fois pour revenir à l'écran précédent."
    );
  }

  Future<void> _testServerConnection() async {
    setState(() {
      statusText = "Test de connexion au serveur...";
    });

    try {
      final response = await http
          .get(Uri.parse('$serverUrl/ping'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _serverConnected = true;
          statusText = "Connecté au serveur ✓";
        });
        await flutterTts.speak("Connecté au serveur avec succès");
        print("Connexion au serveur réussie: ${response.body}");
      } else {
        setState(() {
          _serverConnected = false;
          statusText = "Erreur de connexion: ${response.statusCode}";
        });
        await flutterTts.speak("Erreur de connexion au serveur");
        print("Erreur de connexion: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      setState(() {
        _serverConnected = false;
        statusText = "Erreur de connexion: $e";
      });
      await flutterTts.speak("Impossible de se connecter au serveur de détection");
      print("Exception lors du test de connexion: $e");
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    try {
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isControllerInitialized = true;
        statusText = "Caméra initialisée";
      });
      print("Caméra initialisée avec succès");
    } catch (e) {
      setState(() {
        statusText = "Erreur d'initialisation de la caméra: $e";
      });
      await flutterTts.speak("Erreur d'initialisation de la caméra");
      print('Erreur d\'initialisation de la caméra: $e');
    }
  }

  Future<void> _initializeTTS() async {
    flutterTts = FlutterTts();
    try {
      await flutterTts.setLanguage("fr-FR");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);

      // Ajout d'un événement de complétion pour savoir quand la parole est terminée
      flutterTts.setCompletionHandler(() {
        print("TTS: Lecture terminée");
      });

      print("TTS initialisé avec succès");
    } catch (e) {
      print("Erreur d'initialisation du TTS: $e");
    }
  }

  void startRealTimeDetection() {
    if (!_isControllerInitialized || isStreaming) return;

    isStreaming = true;
    _successfulRequests = 0;
    _failedRequests = 0;
    _lastAnnouncedObjects.clear();

    setState(() {
      statusText = "Démarrage de la détection en temps réel...";
    });

    flutterTts.speak("Démarrage de la détection d'objets");

    // Démarrer le flux d'images
    _controller.startImageStream((CameraImage image) {
      _currentCameraImage = image;
    });

    // Timer pour traiter les images à intervalles réguliers
    _processingTimer = Timer.periodic(Duration(milliseconds: _frameInterval), (timer) {
      _processCurrentFrame();
    });
  }

  Future<void> _processCurrentFrame() async {
    // Vérifier si nous sommes déjà en train de traiter une image
    if (isDetecting || _currentCameraImage == null) return;

    // Vérifier l'intervalle entre les frames
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < _frameInterval) return;
    _lastFrameTime = now;

    isDetecting = true;
    final startTime = DateTime.now();

    try {
      // Capturer une image de haute qualité
      XFile picture = await _controller.takePicture();
      var bytes = await picture.readAsBytes();
      String base64Image = base64Encode(bytes);

      print("Image capturée pour analyse, taille: ${bytes.length} bytes");

      // Envoyer l'image au serveur
      final response = await http
          .post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      )
          .timeout(const Duration(seconds: 5));

      final processingTime = DateTime.now().difference(startTime).inMilliseconds;

      // Mise à jour des statistiques
      _successfulRequests++;
      _averageResponseTime = ((_averageResponseTime * (_successfulRequests - 1)) + processingTime) / _successfulRequests;

      print("Réponse reçue en ${processingTime}ms");

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        List<dynamic> objects = data['objects'] ?? [];

        // Extraire les boîtes de détection si disponibles
        _detectionBoxes = [];
        if (data.containsKey('boxes')) {
          _detectionBoxes = List<Map<String, dynamic>>.from(data['boxes']);
        }

        if (objects.isNotEmpty) {
          // Convertir la liste en Set pour comparaison rapide
          Set<String> currentObjects = Set<String>.from(objects);

          // Identifier les nouveaux objets
          Set<String> newObjects = currentObjects.difference(_lastAnnouncedObjects);

          setState(() {
            detectedObjectsText = objects.join(", ");
            processedImageBytes = base64Decode(data['image']);
            statusText = "Détection: ${objects.length} objets en ${processingTime}ms";
          });

          // Ne pas parler trop souvent pour éviter le chevauchement
          final timeSinceLastAnnouncement = DateTime.now().difference(_lastAnnouncementTime).inSeconds;

          if (newObjects.isNotEmpty && timeSinceLastAnnouncement >= 3) {
            // Compter les objets pour une meilleure description vocale
            if (newObjects.length == 1) {
              await flutterTts.speak("J'ai détecté un ${newObjects.first}");
            } else if (newObjects.length <= 3) {
              await flutterTts.speak("J'ai détecté: ${newObjects.join(", ")}");
            } else {
              await flutterTts.speak("J'ai détecté ${newObjects.length} objets, notamment: ${newObjects.take(3).join(", ")}");
            }

            _lastAnnouncementTime = DateTime.now();
            print("Nouveaux objets annoncés: ${newObjects.join(", ")}");
          }

          // Mettre à jour les objets déjà annoncés
          _lastAnnouncedObjects = currentObjects;
        } else {
          setState(() {
            detectedObjectsText = "";
            processedImageBytes = base64Decode(data['image']);
            statusText = "Aucun objet détecté";
          });

          // Annoncer l'absence d'objets occasionnellement
          final timeSinceLastAnnouncement = DateTime.now().difference(_lastAnnouncementTime).inSeconds;
          if (_lastAnnouncedObjects.isNotEmpty && timeSinceLastAnnouncement >= 5) {
            await flutterTts.speak("Je ne vois plus d'objets");
            _lastAnnouncementTime = DateTime.now();
          }

          _lastAnnouncedObjects.clear();
        }
      } else {
        _failedRequests++;
        setState(() {
          statusText = "Erreur serveur: ${response.statusCode}";
        });
        print("Erreur serveur: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      _failedRequests++;
      setState(() {
        statusText = "Erreur: ${e.toString().substring(0, min(50, e.toString().length))}...";
      });
      print("Exception pendant la détection: $e");
    } finally {
      isDetecting = false;
    }
  }

  void stopDetection() {
    if (!isStreaming) return;

    isStreaming = false;
    _processingTimer?.cancel();
    _controller.stopImageStream();

    setState(() {
      statusText = "Détection arrêtée";
      _detectionBoxes = [];
    });

    flutterTts.speak("Détection d'objets arrêtée");
  }

  void toggleDetection() {
    if (isStreaming) {
      stopDetection();
    } else {
      startRealTimeDetection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gérer le cycle de vie de l'application
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_isControllerInitialized) {
        stopDetection();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopDetection();
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    flutterTts.stop();
    super.dispose();
  }

  // Fonction pour dessiner les rectangles de détection
  Widget _buildDetectionBoxOverlay() {
    if (_detectionBoxes.isEmpty) return Container();

    return CustomPaint(
      size: Size.infinite,
      painter: DetectionBoxPainter(_detectionBoxes),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    if (!_isControllerInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détection des objets'),
          backgroundColor: const Color(0xFF003049),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF003049), Color(0xFF8ECAE6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  statusText,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF003049),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Retour à l\'accueil', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détection des objets'),
        backgroundColor: const Color(0xFF003049),
        actions: [
          // Bouton d'aide
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _speakInstructions,
            tooltip: 'Instructions vocales',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF003049), Color(0xFF003049)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview ou image traitée avec détection de tap
                  GestureDetector(
                    onTap: toggleDetection,
                    onDoubleTap: () {
                      flutterTts.speak("Retour à l'écran d'accueil");
                      Future.delayed(const Duration(milliseconds: 800), () {
                        Navigator.of(context).pop();
                      });
                    },
                    child: Semantics(
                      label: isStreaming
                          ? "Caméra active, détection en cours. Appuyez pour arrêter."
                          : "Caméra en pause. Appuyez pour démarrer la détection.",
                      image: true,
                      child: processedImageBytes == null
                          ? CameraPreview(_controller)
                          : Image.memory(processedImageBytes!, fit: BoxFit.contain),
                    ),
                  ),

                  // Overlay des rectangles de détection
                  if (_detectionBoxes.isNotEmpty) _buildDetectionBoxOverlay(),

                  // Indicateur de statut serveur
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _testServerConnection,
                      child: Semantics(
                        button: true,
                        label: _serverConnected
                            ? "Serveur connecté, appuyez pour tester à nouveau"
                            : "Serveur déconnecté, appuyez pour tester à nouveau",
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _serverConnected
                                ? Colors.green.withOpacity(0.7)
                                : Colors.red.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _serverConnected ? "Serveur connecté" : "Serveur déconnecté",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Indicateur d'activité
                  if (isStreaming)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (isDetecting)
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const Text(
                              "Analyse en cours",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Zone d'information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  if (detectedObjectsText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Objets: $detectedObjectsText',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Stats: ${_successfulRequests} OK | ${_failedRequests} Erreurs | ${_averageResponseTime.toStringAsFixed(0)}ms',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ),

                  // Boutons d'action explicites
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: toggleDetection,
                          icon: Icon(isStreaming ? Icons.stop : Icons.play_arrow),
                          label: Text(isStreaming ? 'Arrêter' : 'Démarrer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isStreaming ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (detectedObjectsText.isNotEmpty) {
                              flutterTts.speak(detectedObjectsText);
                            } else {
                              flutterTts.speak("Aucun objet n'est actuellement détecté");
                            }
                          },
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Lire'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Peintre personnalisé pour dessiner les rectangles de détection
class DetectionBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> boxes;

  DetectionBoxPainter(this.boxes);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint textBgPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const TextStyle textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    for (var box in boxes) {
      // Récupérer les coordonnées normalisées (0-1)
      double x = box['x'] ?? 0.0;
      double y = box['y'] ?? 0.0;
      double w = box['width'] ?? 0.0;
      double h = box['height'] ?? 0.0;
      String label = box['label'] ?? 'objet';
      double confidence = box['confidence'] ?? 0.0;

      // Convertir en coordonnées d'écran
      double screenX = x * size.width;
      double screenY = y * size.height;
      double screenW = w * size.width;
      double screenH = h * size.height;

      // Dessiner le rectangle
      canvas.drawRect(Rect.fromLTWH(screenX, screenY, screenW, screenH), paint);

      // Préparer le texte
      String displayText = '$label ${(confidence * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(text: displayText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Dessiner le fond du texte
      canvas.drawRect(
        Rect.fromLTWH(
          screenX,
          screenY - textPainter.height - 4,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        textBgPaint,
      );

      // Dessiner le texte
      textPainter.paint(
        canvas,
        Offset(screenX + 4, screenY - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}