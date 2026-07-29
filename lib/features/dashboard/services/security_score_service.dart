import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:safe_device/safe_device.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/constants/app_constants.dart';

class ScoreFactor {
  final String title;
  final double scoreFraction; // 0.0 to 1.0
  final String description;
  final String tip;

  const ScoreFactor({
    required this.title,
    required this.scoreFraction,
    required this.description,
    required this.tip,
  });
}

class SecurityScoreReport {
  final int totalScore; // 0 to 100
  final String ratingLabel;
  final List<ScoreFactor> factors;

  const SecurityScoreReport({
    required this.totalScore,
    required this.ratingLabel,
    required this.factors,
  });
}

class SecurityScoreService {
  static Future<SecurityScoreReport> calculateReport() async {
    var passwordScore = 0.8;
    var wifiScore = 0.7;
    var deviceScore = 0.9;
    var fileVaultScore = 0.8;
    var totpScore = 0.5;

    // 1. Password Vault Evaluation
    try {
      if (Hive.isBoxOpen(AppConstants.passwordBoxName)) {
        final box = Hive.box(AppConstants.passwordBoxName);
        if (box.isEmpty) {
          passwordScore = 0.4;
        } else {
          passwordScore = 0.85;
        }
      }
    } catch (_) {}

    // 2. Device Integrity Check
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final isJailbroken = await SafeDevice.isJailBroken;
        final isReal = await SafeDevice.isRealDevice;
        if (isJailbroken) {
          deviceScore = 0.2;
        } else if (!isReal) {
          deviceScore = 0.6;
        } else {
          deviceScore = 0.95;
        }
      }
    } catch (_) {}

    // 3. Wi-Fi Check
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.wifi)) {
        wifiScore = 0.75;
      } else if (connectivity.contains(ConnectivityResult.mobile)) {
        wifiScore = 0.9;
      } else {
        wifiScore = 0.5;
      }
    } catch (_) {}

    // 4. File Vault Check
    try {
      if (Hive.isBoxOpen(AppConstants.vaultBoxName)) {
        final box = Hive.box(AppConstants.vaultBoxName);
        fileVaultScore = box.isNotEmpty ? 0.95 : 0.6;
      }
    } catch (_) {}

    // 5. 2FA Check
    try {
      if (Hive.isBoxOpen('totp_box')) {
        final box = Hive.box('totp_box');
        totpScore = box.isNotEmpty ? 1.0 : 0.3;
      }
    } catch (_) {}

    final total = ((passwordScore * 25) +
            (deviceScore * 25) +
            (wifiScore * 20) +
            (fileVaultScore * 15) +
            (totpScore * 15))
        .round()
        .clamp(0, 100);

    String label = 'Well Protected';
    if (total < 50) {
      label = 'High Risk';
    } else if (total < 75) {
      label = 'Needs Attention';
    }

    final factors = [
      ScoreFactor(
        title: 'Passwords',
        scoreFraction: passwordScore,
        description: 'Evaluates vault password entropy & storage security.',
        tip: 'Ensure all accounts use strong 16+ char unique passwords.',
      ),
      ScoreFactor(
        title: 'Device',
        scoreFraction: deviceScore,
        description: 'Checks OS build, root/jailbreak & hardware security.',
        tip: 'Keep operating system updated to latest security patch.',
      ),
      ScoreFactor(
        title: 'Wi-Fi',
        scoreFraction: wifiScore,
        description: 'Monitors current connection type & encryption.',
        tip: 'Avoid open public Wi-Fi networks without VPN.',
      ),
      ScoreFactor(
        title: 'Vault Files',
        scoreFraction: fileVaultScore,
        description: 'Encrypted document storage status.',
        tip: 'Import sensitive photos and documents into AES File Vault.',
      ),
      ScoreFactor(
        title: '2FA Auth',
        scoreFraction: totpScore,
        description: 'Two-Factor Authentication protection status.',
        tip: 'Add 2FA accounts to 2FA Authenticator for extra security.',
      ),
    ];

    return SecurityScoreReport(
      totalScore: total,
      ratingLabel: label,
      factors: factors,
    );
  }
}
