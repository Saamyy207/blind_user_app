import 'package:flutter/material.dart';
import 'package:blind_user_app/views/qr_code_scanner_view.dart';
import 'package:blind_user_app/views/blind_profile_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pkxsyvtbdjeqfhbrspcm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBreHN5dnRiZGplcWZoYnJzcGNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxOTc0NjIsImV4cCI6MjA1OTc3MzQ2Mn0.01rkn6tzYCYHOCFvYuRC1-rtXv96EbwSQlbXbLLmnrc',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionGuard - Blind User',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const QrScannerView(),
    );
  }
}

