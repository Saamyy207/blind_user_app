import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'blind_profile_view.dart';

class QrScannerView extends StatelessWidget {
  const QrScannerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(
        onDetect: (BarcodeCapture capture){
         final List<Barcode> barcodes = capture.barcodes;
         for (final barcode in barcodes) {
           final String? code = barcode.rawValue;
           if(code != null){
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (_) => BlindProfileView(userId: code),
               ),
             );
             break;
           }
         }

        },
      ),
    );
  }
}
