import 'package:blind_user_app/view_models/blinduser_viewmodel.dart';
import 'package:blind_user_app/views/blind_profile_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 à ajouter
 // 👈 à ajuster selon ton arborescence
import 'package:blind_user_app/views/call_redirector.dart';
import 'package:blind_user_app/views/qr_code_scanner_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pkxsyvtbdjeqfhbrspcm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBreHN5dnRiZGplcWZoYnJzcGNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxOTc0NjIsImV4cCI6MjA1OTc3MzQ2Mn0.01rkn6tzYCYHOCFvYuRC1-rtXv96EbwSQlbXbLLmnrc',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => BlindUserViewModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionGuard - Blind User',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: CallRedirector(
        child: BlindProfileView(userId: '4fc39bc9-dfa4-4164-93b9-bcafe6034955',),
      ),
    );
  }
}
