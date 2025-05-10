import 'dart:async';

import 'package:blind_user_app/views/blinduser_homepage.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askLocationSharingPermission();
    });
  }



  Future<void> _askLocationSharingPermission() async {
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Partager votre position"),
        content: const Text("Souhaitez-vous partager votre position avec votre assistant ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Non"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Oui"),
          ),
        ],
      ),
    );

    if (consent == true) {
      print("[DEBUG] L'utilisateur a accepté de partager sa position.");
      await _checkPermission();
      _startTracking();
      print("tracking started");
    }else{
      print("[DEBUG] L'utilisateur a refusé de partager sa position.");
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
    print("[DEBUG] Permission actuelle : $permission");

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      print("[DEBUG] Nouvelle permission après demande : $permission");
    }
  }







  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;

  void _startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // Ne notifie que s'il bouge de plus de 5m
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            print("[DEBUG] Nouvelle position reçue : ${position.latitude}, ${position.longitude}");
        if (_lastPosition == null || _hasMoved(position, _lastPosition!)) {
          _lastPosition = position;
          print("[DEBUG] Mouvement détecté, insertion en cours...");
          try {
            await supabase.from('locations').insert({
              'user_id': widget.userId,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'updated_at': DateTime.now().toIso8601String(),
            });
            print("[DEBUG] Insertion réussie !");
          }catch (e) {
            debugPrint("Erreur d'insertion : $e");
            print("[DEBUG] Erreur d'insertion dans Supabase : $e");
          }
        }
      },
      onError: (error) {
        debugPrint('Erreur de localisation : $error');
      },
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  bool _hasMoved(Position newPos, Position oldPos) {
    const double thresholdInMeters = 5.0;
    double distance = Geolocator.distanceBetween(
      oldPos.latitude,
      oldPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );
    return distance >= thresholdInMeters;
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
            child: const Text("a"),
          ),
          ElevatedButton(
            onPressed: () {
              // Caméra ou autre
            },
            child: const Text("Camera"),
          ),
        ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlindUserHomePage(),
      ),
    );
  },
  child: const Text("appel"),
),

        ],
      ),
    );
  }
}
