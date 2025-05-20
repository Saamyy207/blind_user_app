import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../agora_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class BlindUserViewModel extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  final supabase = Supabase.instance.client;
  final player = AudioPlayer();
  RealtimeChannel? _channel;

  late final RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isInCall = false;
  bool _isRinging = false;

  bool get isInCall => _isInCall;
  bool get localUserJoined => _localUserJoined;
  int? get remoteUid => _remoteUid;
  RtcEngine get engine => _engine;
  bool get isRinging => _isRinging;

  final int localUid = 2;
  final String channelName = AgoraConfig.channelName;

  BlindUserViewModel() {
    _initAgora();
    _listenForIncomingCalls();
  }

  Future<void> speak(String message) async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(message);
  }

  Future<void> _initAgora() async {
    await _requestPermissions();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));
    await _engine.enableVideo();
    await _engine.enableAudio();
    await engine.switchCamera();
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('✅ Local user joined: ${connection.localUid}');
          _localUserJoined = true;
          notifyListeners();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('👤 Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          _stopRinging();
          speak("L'appel a commencé. Pour raccrocher, double tapez l'écran.");
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('❌ Remote user left: $remoteUid');
          _remoteUid = null;
          notifyListeners();
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          print("⚠ [CONNECTION] État de connexion: $state, raison: $reason");
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 800,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

void _listenForIncomingCalls() {
  print('🔍 Écoute des appels entrants...');
  _channel = supabase.channel('calls_channel');

  _channel!
    ..onBroadcast(
      event: 'incoming_call',
      callback: (payload) async {
        print('📞 Appel entrant détecté: $payload');
        await _startRinging();
      },
    )
    ..onBroadcast(
      event: 'call_end_assistant',
      callback: (payload) async {
        print('📴 L\'assistant a mis fin à l\'appel: $payload');
        if (_isInCall) {
          await speak("L'appel a été terminé par l'assistant.");
          await endCall();
        }
      },
    )
    ..subscribe(
      (status, error) {
        print('📡 Abonnement: $status, erreur: $error');
      },
    );
}


  Future<void> _startRinging() async {
    print('🔔 Sonnerie démarrée');
    _isRinging = true;
    notifyListeners();

    // 1. Démarre la sonnerie immédiatement
    await player.setReleaseMode(ReleaseMode.loop);
    try {
      await player.play(AssetSource('sounds/ringtone.mp3'));
    } catch (_) {
      try {
        await player.play(AssetSource('assets/sounds/ringtone.mp3'));
      } catch (e) {
        print('❌ Échec sonnerie : $e');
      }
    }

    // 2. Parle après un petit délai (ex: 2 secondes)
    Future.delayed(const Duration(seconds: 2), () async {
      await speak("Appel entrant. Tapez une fois pour répondre, deux fois pour rejeter.");
    });
  }

  Future<void> _stopRinging() async {
    if (_isRinging) {
      print('🔕 Sonnerie arrêtée');
      await player.stop();
      _isRinging = false;
      notifyListeners();
    }
  }

  Future<void> acceptCall() async {
    await _stopRinging();
    await speak("Appel accepté.");
    await startCall();
  }

  Future<void> rejectCall() async {
    await _stopRinging();
    await speak("Appel rejeté.");

    if (_channel != null) {
      try {
        await _channel!.sendBroadcastMessage(
          event: 'call_rejected',
          payload: {
            "uid": localUid,
            "timestamp": DateTime.now().toIso8601String()
          },
        );
        await _channel!.sendBroadcastMessage(
          event: 'call_end',
          payload: {
            "uid": localUid,
            "status": "rejected",
            "timestamp": DateTime.now().toIso8601String()
          },
        );
      } catch (e) {
        print('❌ Erreur envoi rejet: $e');
      }
    }
  }

  Future<void> startCall() async {
    if (_isInCall) {
      print("⚠️ Un appel est déjà en cours.");
      return;
    }
    await _engine.startPreview();
    await _engine.joinChannel(
      token: AgoraConfig.token,
      channelId: channelName,
      uid: localUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
    _isInCall = true;
    notifyListeners();
  }

  Future<void> endCall() async {
    try {
      await _engine.leaveChannel();
      _isInCall = false;
      _localUserJoined = false;
      _remoteUid = null;
      notifyListeners();

      await speak("Appel terminé.");

      if (_channel != null) {
        await _channel!.sendBroadcastMessage(
          event: 'call_ended',
          payload: {
            "uid": localUid,
            "timestamp": DateTime.now().toIso8601String()
          },
        );
        await _channel!.sendBroadcastMessage(
          event: 'call_end',
          payload: {
            "uid": localUid,
            "status": "ended",
            "timestamp": DateTime.now().toIso8601String()
          },
        );
      }
    } catch (e) {
      print('❌ Erreur lors de endCall: $e');
    }
  }
Future<void> toggleCamera() async {
  await engine.switchCamera();
  await speak("Changement de caméra");
}


  @override
  void dispose() {
    _stopRinging();
    player.dispose();
    _channel?.unsubscribe();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }
}