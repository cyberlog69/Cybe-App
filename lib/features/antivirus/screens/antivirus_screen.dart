import 'package:flutter/material.dart';
import '../../vulnerability_scan/screens/vulnerability_scan_screen.dart';

/// Legacy AntivirusScreen wrapper forwarding to the unified Vulnerability & Antivirus Security Suite
class AntivirusScreen extends StatelessWidget {
  const AntivirusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VulnerabilityScanScreen();
  }
}
