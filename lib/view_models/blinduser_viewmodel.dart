import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../agora_config.dart';

class BlindUserViewModel extends ChangeNotifier {
  late final RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isInCall = false;

  bool get isInCall => _isInCall;
  bool get localUserJoined => _localUserJoined;
  int? get remoteUid => _remoteUid;
  RtcEngine get engine => _engine;

  final int localUid = 2;
  final String channelName = AgoraConfig.channelName;

  BlindUserViewModel() {
    _initAgora();
  }

  Future<void> _initAgora() async {
    await _requestPermissions();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));
    await _engine.enableVideo();
    await _engine.enableAudio();

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        _localUserJoined = true;
        notifyListeners();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        _remoteUid = remoteUid;
        notifyListeners();
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        _remoteUid = null;
        notifyListeners();
      },
    ));

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

  Future<void> startCall() async {
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
    await _engine.leaveChannel();
    _isInCall = false;
    _localUserJoined = false;
    _remoteUid = null;
    notifyListeners();
  }

  Future<void> disposeEngine() async {
    await _engine.leaveChannel();
    await _engine.release();
  }
}
