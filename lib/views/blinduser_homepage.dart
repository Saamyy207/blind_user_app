import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../agora_config.dart';

class BlindUserHomePage extends StatefulWidget {
  @override
  _BlindUserHomePageState createState() => _BlindUserHomePageState();
}

class _BlindUserHomePageState extends State<BlindUserHomePage> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isInCall = false;

  final String channelName = AgoraConfig.channelName;
  final int uid = 2; // UID de l'utilisateur aveugle

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await _requestPermissions();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));

    await _engine.enableVideo();
    await _engine.enableAudio();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('✅ Local user joined: ${connection.localUid}');
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('👤 Remote user joined: $remoteUid');
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('❌ Remote user left: $remoteUid');
          setState(() => _remoteUid = null);
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

  Future<void> _toggleCall() async {
    if (_isInCall) {
      await _engine.leaveChannel();
      setState(() {
        _isInCall = false;
        _localUserJoined = false;
        _remoteUid = null;
      });
    } else {
      await _engine.startPreview(); // ✅ Important : preview avant join
      await _engine.joinChannel(
        token: AgoraConfig.token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );

      setState(() {
        _isInCall = true;
      });
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("App de l'aveugle")),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _isInCall
                  ? Stack(
                      children: [
                        _remoteUid != null
                            ? AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: _engine,
                                  canvas: VideoCanvas(uid: _remoteUid),
                                  connection: RtcConnection(channelId: channelName),
                                ),
                              )
                            : Center(
                                child: Text(
                                  "En attente de l'assistant...",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                        if (_localUserJoined)
                          Positioned(
                            top: 16,
                            right: 16,
                            width: 120,
                            height: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: _engine,
                                  canvas: const VideoCanvas(uid: 2), // Même UID que le `joinChannel`
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Text(
                        "Appuyez sur Démarrer l'appel",
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
            ),
          ),
          Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton(
              onPressed: _toggleCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isInCall ? Colors.red : Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isInCall ? Icons.call_end : Icons.call),
                  SizedBox(width: 8),
                  Text(_isInCall ? "Terminer l'appel" : "Démarrer l'appel"),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
