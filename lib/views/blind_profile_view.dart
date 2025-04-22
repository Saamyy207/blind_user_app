import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlindProfileView extends StatefulWidget {
  final String userId;
  const BlindProfileView({super.key, required this.userId});

  @override
  State<BlindProfileView> createState() => _BlindProfileViewState();
}

class _BlindProfileViewState extends State<BlindProfileView> {
  final SupabaseClient supabase = Supabase.instance.client;
  String userName = "";

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _checkPermission().then((_) {
      _startTracking();
    });
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              // Tu peux ouvrir une carte ici ou continuer à tracker
            },
            child: const Text("Map"),
          ),
          ElevatedButton(
            onPressed: () {
              // Caméra ou autre
            },
            child: const Text("Camera"),
          ),
          ElevatedButton(
            onPressed: () {
              // Chat, ou rediriger vers un autre écran
            },
            child: const Text("Chat"),
          ),
        ],
      ),
    );
  }
}
