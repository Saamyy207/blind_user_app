import 'package:blind_user_app/view_models/blinduser_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:provider/provider.dart';
import '../agora_config.dart';

class BlindUserHomePage extends StatelessWidget {
  const BlindUserHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blindUserViewModel = Provider.of<BlindUserViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("App de l'aveugle")),
      body: ListenableBuilder(
        listenable: blindUserViewModel,
        builder: (context, child) {
          if (blindUserViewModel.isRinging && !blindUserViewModel.isInCall) {
            return _buildIncomingCallView(blindUserViewModel);
          }

          if (blindUserViewModel.isInCall) {
            return _buildCallView(blindUserViewModel);
          }

          return _buildWaitingView();
        },
      ),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_disabled, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            "En attente d'un appel de l'assistant",
            style: TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "Vous serez notifié lorsqu'un appel entrant arrive",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCallView(BlindUserViewModel viewModel) {
    return GestureDetector(
      onTap: viewModel.acceptCall,
      onDoubleTap: viewModel.rejectCall,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.call_received,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                "Appel entrant de l'assistant",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(16),
                      shape: const CircleBorder(),
                    ),
                    onPressed: viewModel.rejectCall,
                    child: const Icon(Icons.call_end, size: 30),
                  ),
                  const SizedBox(width: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                      shape: const CircleBorder(),
                    ),
                    onPressed: viewModel.acceptCall,
                    child: const Icon(Icons.call, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "👆 Tapez une fois pour répondre\n✌️ Double tapez pour rejeter",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallView(BlindUserViewModel viewModel) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                viewModel.remoteUid != null
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: viewModel.engine,
                          canvas: VideoCanvas(uid: viewModel.remoteUid),
                          connection: RtcConnection(channelId: AgoraConfig.channelName),
                        ),
                      )
                    : const Center(
                        child: Text(
                          "En attente de l'assistant...",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                if (viewModel.localUserJoined)
                  Positioned(
                    top: 16,
                    right: 16,
                    width: 120,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: viewModel.engine,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.grey.shade900,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: ElevatedButton(
              onPressed: viewModel.endCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.call_end),
                  SizedBox(width: 8),
                  Text("Terminer l'appel"),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }
}
