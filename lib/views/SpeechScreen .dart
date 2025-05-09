import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({Key? key}) : super(key: key);

  @override
  State<AIAgentScreen> createState() => _AIAgentScreenState();
}

class _AIAgentScreenState extends State<AIAgentScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isResponseBeingSpoken = false;
  String _lastWords = '';
  String _lastProcessedText = '';
  List<ConversationItem> _history = [];

  // URL du webhook N8N via ngrok - à mettre à jour selon vos besoins
  final String webhookUrl = 'https://e8c3-196-116-184-148.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    _initServices();
    // Annoncer vocalement que l'écran est prêt
    Future.delayed(const Duration(milliseconds: 500), () {
      _speak("Agent IA prêt. Appuyez n'importe où sur l'écran et maintenez pour parler.");
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  // Initialiser tous les services nécessaires
  Future<void> _initServices() async {
    await _initSpeech();
    await _initTts();
  }

  // Initialiser la synthèse vocale
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.9); // Vitesse légèrement plus lente pour plus de clarté
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isResponseBeingSpoken = false;
        });
      }
    });
  }

  // Lire un texte à haute voix
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isResponseBeingSpoken = true;
    });

    await _flutterTts.speak(text);
  }

  // Initialiser la reconnaissance vocale
  Future<void> _initSpeech() async {
    await Permission.microphone.request();

    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        print("Speech status: $status");
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;

              // Envoyer le texte au webhook si des mots ont été reconnus
              if (_lastWords.isNotEmpty && _lastWords != _lastProcessedText) {
                _lastProcessedText = _lastWords;
                _sendToWebhook(_lastWords);
              }
            });
          }
        }
      },
      onError: (errorNotification) {
        print("Speech error: $errorNotification");
        if (mounted) {
          setState(() {
            _isListening = false;
          });
          _speak("Erreur de reconnaissance vocale. Veuillez réessayer.");
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  // Envoyer le texte au webhook et recevoir la réponse
  Future<void> _sendToWebhook(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Ajouter le message utilisateur à l'historique
      _addToHistory(text, isUser: true);

      // Préparer les données à envoyer
      final Map<String, dynamic> data = {'message': text};

      // URL complète avec le chemin du webhook
      final String fullUrl = '$webhookUrl/webhook-test/27658c0e-e344-409b-8208-64b6a09447a4/chat';

      // Annoncer l'envoi
      _speak("Envoi de votre message");

      // Envoyer la requête POST avec un timeout
      final response = await http
          .post(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('La connexion au webhook a expiré');
        },
      );

      if (response.statusCode == 200) {
        // Traiter la réponse
        try {
          final List<dynamic> responseList = jsonDecode(response.body);
          if (responseList.isNotEmpty && responseList[0] is Map<String, dynamic>) {
            final Map<String, dynamic> firstItem = responseList[0];
            final aiResponse = firstItem['output'] ?? "Pas de réponse";

            // Ajouter la réponse à l'historique
            _addToHistory(aiResponse, isUser: false);

            // Lire la réponse à haute voix
            _speak(aiResponse);
          } else {
            _addToHistory("Format de réponse inattendu", isUser: false);
            _speak("Format de réponse inattendu");
          }
        } catch (e) {
          // Si la réponse n'est pas un JSON valide, l'utiliser comme texte brut
          if (response.body.isNotEmpty) {
            _addToHistory(response.body, isUser: false);
            _speak("Erreur dans le format de la réponse");
          } else {
            _addToHistory("Réponse vide ou invalide", isUser: false);
            _speak("Réponse vide ou invalide");
          }
        }
      } else {
        final errorMsg = "Erreur de communication avec l'agent IA (${response.statusCode})";
        _addToHistory(errorMsg, isUser: false);
        _speak(errorMsg);
      }
    } catch (e) {
      String errorMsg;
      if (e is TimeoutException) {
        errorMsg = "Erreur: Connexion au webhook expirée. Vérifiez que le service est en cours d'exécution et accessible.";
      } else {
        errorMsg = "Erreur de connexion: Impossible de joindre le webhook. Vérifiez votre connexion internet.";
      }
      _addToHistory(errorMsg, isUser: false);
      _speak("Erreur de connexion");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Ajouter un message à l'historique
  void _addToHistory(String message, {required bool isUser}) {
    setState(() {
      _history.add(
        ConversationItem(
          message: message,
          isUser: isUser,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Faire défiler automatiquement vers le bas
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Démarrer ou arrêter l'écoute
  void _toggleListening() async {
    // Si une réponse est en cours de lecture, l'arrêter
    if (_isResponseBeingSpoken) {
      await _flutterTts.stop();
      setState(() {
        _isResponseBeingSpoken = false;
      });
      return;
    }

    // Si on est en train de traiter une demande, ne rien faire
    if (_isProcessing) return;

    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_speechEnabled) {
      if (_isListening) {
        await _speechToText.stop();
        setState(() {
          _isListening = false;
        });
      } else {
        // Réinitialiser le dernier texte traité pour permettre de répéter le même message
        _lastProcessedText = '';
        setState(() {
          _isListening = true;
          _lastWords = '';
        });

        final feedback = "Je vous écoute";
        _speak(feedback);

        await _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _lastWords = result.recognizedWords;

                // Si c'est le résultat final et que nous avons des mots
                if (result.finalResult && result.recognizedWords.isNotEmpty && result.recognizedWords != _lastProcessedText) {
                  _isListening = false;
                  _lastProcessedText = result.recognizedWords;
                  _sendToWebhook(result.recognizedWords);
                }
              });
            }
          },
          localeId: 'fr_FR',
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 3),
          listenMode: ListenMode.confirmation,
        );
      }
    } else {
      _speak("La reconnaissance vocale n'est pas disponible");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent IA pour assistance visuelle'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Retour',
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _history.clear();
                  _lastProcessedText = '';
                });
                _speak("Historique de conversation effacé");
              },
              tooltip: 'Effacer l\'historique',
            ),
        ],
      ),
      body: GestureDetector(
        onLongPress: _toggleListening,
        onLongPressEnd: (_) {
          if (_isListening) {
            _speechToText.stop();
            setState(() {
              _isListening = false;
            });
          }
        },
        child: Container(
          color: Colors.transparent, // Pour permettre les gestes sur toute la surface
          child: Column(
            children: [
              // Indicateur de statut
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: _getStatusColor().withOpacity(0.2),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Zone d'affichage du texte reconnu
              if (_isListening || _lastWords.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: _getStatusColor().withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _isListening
                        ? (_lastWords.isEmpty ? "Je vous écoute..." : _lastWords)
                        : _lastWords,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Historique des conversations
              Expanded(
                child: _history.isEmpty
                    ? _buildEmptyHistoryView()
                    : _buildConversationHistory(),
              ),

              // Instructions d'utilisation en bas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.deepPurple.shade50,
                child: const Text(
                  'Appuyez longuement sur l\'écran pour parler à l\'agent IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
      // Bouton flottant pour démarrer/arrêter l'écoute
      floatingActionButton: FloatingActionButton.large(
        onPressed: _toggleListening,
        backgroundColor: _getStatusColor(),
        elevation: 8,
        tooltip: _getActionButtonTooltip(),
        child: Icon(
          _getActionButtonIcon(),
          size: 36,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Vue lorsque l'historique est vide
  Widget _buildEmptyHistoryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.deepPurple.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune conversation',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Appuyez longuement sur l\'écran ou sur le bouton pour commencer à parler',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Construction de l'historique des conversations
  Widget _buildConversationHistory() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return _buildConversationBubble(item);
      },
    );
  }

  // Construction d'une bulle de conversation
  Widget _buildConversationBubble(ConversationItem item) {
    return Semantics(
      label: item.isUser
          ? "Vous avez dit: ${item.message}"
          : "Agent IA a répondu: ${item.message}",
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        alignment: item.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isUser ? Colors.deepPurple.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: item.isUser
                  ? Colors.deepPurple.shade300
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec icône et nom
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isUser ? Icons.person : Icons.smart_toy,
                    size: 20,
                    color: item.isUser
                        ? Colors.deepPurple.shade700
                        : Colors.teal.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.isUser ? 'Vous' : 'Agent IA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: item.isUser
                          ? Colors.deepPurple.shade700
                          : Colors.teal.shade700,
                    ),
                  ),
                  // Bouton pour relire le message
                  if (!item.isUser)
                    IconButton(
                      icon: Icon(
                        Icons.volume_up,
                        size: 20,
                        color: Colors.teal.shade700,
                      ),
                      onPressed: () => _speak(item.message),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Relire ce message',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Message
              Text(
                item.message,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
              // Heure du message
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _formatTime(item.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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

  // Formater l'heure
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Obtenir l'icône de statut
  IconData _getStatusIcon() {
    if (_isListening) return Icons.mic;
    if (_isProcessing) return Icons.sync;
    if (_isResponseBeingSpoken) return Icons.volume_up;
    return Icons.mic_none;
  }

  // Obtenir la couleur de statut
  Color _getStatusColor() {
    if (_isListening) return Colors.red;
    if (_isProcessing) return Colors.orange;
    if (_isResponseBeingSpoken) return Colors.teal;
    return Colors.deepPurple;
  }

  // Obtenir le texte de statut
  String _getStatusText() {
    if (_isListening) return 'Écoute en cours...';
    if (_isProcessing) return 'Traitement en cours...';
    if (_isResponseBeingSpoken) return 'Lecture de la réponse...';
    return 'Prêt à vous écouter';
  }

  // Obtenir l'icône du bouton d'action
  IconData _getActionButtonIcon() {
    if (_isListening) return Icons.mic_off;
    if (_isProcessing) return Icons.hourglass_empty;
    if (_isResponseBeingSpoken) return Icons.volume_off;
    return Icons.mic;
  }

  // Obtenir le tooltip du bouton d'action
  String _getActionButtonTooltip() {
    if (_isListening) return 'Arrêter l\'écoute';
    if (_isProcessing) return 'Traitement en cours';
    if (_isResponseBeingSpoken) return 'Arrêter la lecture';
    return 'Commencer l\'écoute';
  }
}

// Classe pour représenter un élément de conversation
class ConversationItem {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  ConversationItem({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });
}