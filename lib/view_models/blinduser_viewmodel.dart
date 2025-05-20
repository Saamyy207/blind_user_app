import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../agora_config.dart';

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
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(message);
  }

  Future<void> _initAgora() async {
    await _requestPermissions();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));

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
          speak("Call started. To hang up, double tap the screen.");
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('❌ Remote user left: $remoteUid');
          _remoteUid = null;
          notifyListeners();
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          print("⚠ [CONNECTION] State: $state, Reason: $reason");
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.setCameraCapturerConfiguration(
      const CameraCapturerConfiguration(cameraDirection: CameraDirection.cameraFront),
    );
    await _engine.startPreview();
    await _engine.enableAudio();
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 800,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  void _listenForIncomingCalls() {
    print('🔍 Listening for incoming calls...');
    _channel = supabase.channel('calls_channel');

    _channel!
      ..onBroadcast(
        event: 'incoming_call',
        callback: (payload) async {
          print('📞 Incoming call detected: $payload');
          await _startRinging();
        },
      )
      ..onBroadcast(
        event: 'call_end_assistant',
        callback: (payload) async {
          print('📴 Assistant ended the call: $payload');
          if (_isInCall) {
            await speak("The assistant has ended the call.");
            await endCall();
          }
        },
      )
      ..subscribe((status, error) {
        print('📡 Subscribed: $status, error: $error');
      });
  }

  Future<void> _startRinging() async {
    print('🔔 Ringtone started');
    _isRinging = true;
    notifyListeners();

    await player.setReleaseMode(ReleaseMode.loop);
    try {
      await player.play(AssetSource('sounds/ringtone.mp3'));
    } catch (_) {
      try {
        await player.play(AssetSource('assets/sounds/ringtone.mp3'));
      } catch (e) {
        print('❌ Failed to play ringtone: $e');
      }
    }

    Future.delayed(const Duration(seconds: 2), () async {
      await speak("Incoming call from assistant. Tap once to answer, twice to reject.");
    });
  }
Future<void> toggleCamera() async {
  try {
    await _engine.switchCamera();
    print('📸 Camera switched');
    speak('camera switched');
  } catch (e) {
    print('❌ Failed to switch camera: $e');
  }
}

  Future<void> _stopRinging() async {
    if (_isRinging) {
      print('🔕 Ringtone stopped');
      await player.stop();
      _isRinging = false;
      notifyListeners();
    }
  }

  Future<void> acceptCall() async {
    await _stopRinging();
    await speak("Call accepted.");
    await startCall();
  }

  Future<void> rejectCall() async {
    await _stopRinging();
    await speak("Call rejected.");
    if (_channel != null) {
      try {
        await _channel!.sendBroadcastMessage(
          event: 'call_rejected',
          payload: {"uid": localUid, "timestamp": DateTime.now().toIso8601String()},
        );
        await _channel!.sendBroadcastMessage(
          event: 'call_end',
          payload: {"uid": localUid, "status": "rejected", "timestamp": DateTime.now().toIso8601String()},
        );
      } catch (e) {
        print('❌ Error sending rejection: $e');
      }
    }
  }

  Future<void> startCall() async {
    if (_isInCall) {
      print("⚠️ A call is already in progress.");
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

      await speak("Call ended.");

      if (_channel != null) {
        await _channel!.sendBroadcastMessage(
          event: 'call_ended',
          payload: {"uid": localUid, "timestamp": DateTime.now().toIso8601String()},
        );
        await _channel!.sendBroadcastMessage(
          event: 'call_end',
          payload: {"uid": localUid, "status": "ended", "timestamp": DateTime.now().toIso8601String()},
        );
      }
    } catch (e) {
      print('❌ Error during endCall: $e');
    }
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
