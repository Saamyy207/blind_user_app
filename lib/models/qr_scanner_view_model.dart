import 'package:flutter/material.dart';

class QrScannerViewModel extends ChangeNotifier {
  String? scannedData;

  void handleQrScan(String code, BuildContext context) {
    scannedData = code;
    notifyListeners();

    // You can use Navigator or go_router depending on your setup
    Navigator.pushNamed(context, '/blind_user_account', arguments: scannedData);
  }
}
