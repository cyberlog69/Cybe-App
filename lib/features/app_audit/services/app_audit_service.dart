import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_permission_info.dart';

class AppAuditService {
  static const MethodChannel _channel = MethodChannel('com.cybe.cybe_app/app_audit');

  /// Fetches installed apps and performs security risk analysis on requested permissions
  static Future<List<AppPermissionInfo>> getInstalledApps({bool includeSystemApps = false}) async {
    if (!Platform.isAndroid) {
      return _generateMockAuditApps();
    }

    try {
      final List<dynamic>? rawList = await _channel.invokeMethod('getInstalledApps', {
        'includeSystemApps': includeSystemApps,
      });

      if (rawList == null) return [];

      final List<AppPermissionInfo> apps = [];

      for (final raw in rawList) {
        final map = Map<String, dynamic>.from(raw as Map);
        final appName = map['appName'] as String? ?? 'Unknown Application';
        final packageName = map['packageName'] as String? ?? '';
        final versionName = map['versionName'] as String? ?? '1.0.0';
        final isSystemApp = map['isSystemApp'] as bool? ?? false;
        final permissions = (map['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
        final iconBytes = map['iconBytes'] != null
            ? Uint8List.fromList(List<int>.from(map['iconBytes'] as List))
            : null;

        final riskScore = _calculateRiskScore(permissions, isSystemApp);
        final riskLevel = _classifyRiskLevel(riskScore, permissions);

        apps.add(AppPermissionInfo(
          appName: appName,
          packageName: packageName,
          versionName: versionName,
          isSystemApp: isSystemApp,
          permissions: permissions,
          iconBytes: iconBytes,
          riskScore: riskScore,
          riskLevel: riskLevel,
        ));
      }

      // Sort by highest risk score first
      apps.sort((a, b) => b.riskScore.compareTo(a.riskScore));
      return apps;
    } catch (e) {
      debugPrint('[AppAuditService] MethodChannel error: $e');
      return _generateMockAuditApps();
    }
  }

  /// Opens system App Info page to allow user to manage or revoke app permissions
  static Future<bool> openAppDetails(String packageName) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openAppDetails', {
        'packageName': packageName,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[AppAuditService] Error opening app details: $e');
      return false;
    }
  }

  /// Calculates privacy risk score (0 to 100) based on permission danger weights
  static int _calculateRiskScore(List<String> permissions, bool isSystemApp) {
    int score = 0;

    for (final perm in permissions) {
      final uPerm = perm.toUpperCase();

      if (uPerm.contains('RECORD_AUDIO') || uPerm.contains('MICROPHONE')) {
        score += 25;
      } else if (uPerm.contains('CAMERA')) {
        score += 25;
      } else if (uPerm.contains('ACCESS_FINE_LOCATION') || uPerm.contains('ACCESS_BACKGROUND_LOCATION')) {
        score += 20;
      } else if (uPerm.contains('READ_SMS') || uPerm.contains('SEND_SMS') || uPerm.contains('RECEIVE_SMS')) {
        score += 20;
      } else if (uPerm.contains('READ_CONTACTS') || uPerm.contains('WRITE_CONTACTS')) {
        score += 15;
      } else if (uPerm.contains('READ_PHONE_STATE') || uPerm.contains('READ_CALL_LOG')) {
        score += 15;
      } else if (uPerm.contains('STORAGE') || uPerm.contains('READ_MEDIA')) {
        score += 10;
      } else if (uPerm.contains('BLUETOOTH_CONNECT') || uPerm.contains('BLUETOOTH_SCAN')) {
        score += 10;
      } else if (uPerm.contains('SYSTEM_ALERT_WINDOW')) {
        score += 15;
      }
    }

    // System apps get a slight trust offset
    if (isSystemApp) score = (score * 0.7).toInt();

    return score.clamp(0, 100);
  }

  static String _classifyRiskLevel(int score, List<String> permissions) {
    final hasCritical = permissions.any((p) {
      final up = p.toUpperCase();
      return up.contains('CAMERA') ||
          up.contains('RECORD_AUDIO') ||
          up.contains('LOCATION') ||
          up.contains('SMS');
    });

    if (score >= 45 || (hasCritical && score >= 35)) {
      return 'High Risk';
    } else if (score >= 20) {
      return 'Medium Risk';
    }
    return 'Safe';
  }

  /// Mock data fallback for Desktop, Web, or Emulator testing
  static List<AppPermissionInfo> _generateMockAuditApps() {
    final mockApps = [
      const AppPermissionInfo(
        appName: 'SocialConnect Messenger',
        packageName: 'com.social.messenger.app',
        versionName: '4.12.0',
        isSystemApp: false,
        permissions: [
          'android.permission.CAMERA',
          'android.permission.RECORD_AUDIO',
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.READ_CONTACTS',
          'android.permission.READ_PHONE_STATE',
          'android.permission.READ_EXTERNAL_STORAGE',
        ],
        riskScore: 95,
        riskLevel: 'High Risk',
      ),
      const AppPermissionInfo(
        appName: 'QuickFlash Torch & Cam',
        packageName: 'com.utility.quickflash',
        versionName: '2.1.0',
        isSystemApp: false,
        permissions: [
          'android.permission.CAMERA',
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.READ_CONTACTS',
          'android.permission.READ_PHONE_STATE',
        ],
        riskScore: 75,
        riskLevel: 'High Risk',
      ),
      const AppPermissionInfo(
        appName: 'Pixel Photo Editor',
        packageName: 'com.photo.editor.pro',
        versionName: '3.8.5',
        isSystemApp: false,
        permissions: [
          'android.permission.CAMERA',
          'android.permission.READ_EXTERNAL_STORAGE',
          'android.permission.WRITE_EXTERNAL_STORAGE',
        ],
        riskScore: 35,
        riskLevel: 'Medium Risk',
      ),
      const AppPermissionInfo(
        appName: 'Weather Radar 360',
        packageName: 'com.weather.radar',
        versionName: '1.5.2',
        isSystemApp: false,
        permissions: [
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
        ],
        riskScore: 20,
        riskLevel: 'Medium Risk',
      ),
      const AppPermissionInfo(
        appName: 'Cybe Security Suite',
        packageName: 'com.cybe.cybe_app',
        versionName: '1.0.0',
        isSystemApp: false,
        permissions: [
          'android.permission.INTERNET',
          'android.permission.ACCESS_NETWORK_STATE',
          'android.permission.USE_BIOMETRIC',
        ],
        riskScore: 5,
        riskLevel: 'Safe',
      ),
    ];
    return mockApps;
  }
}
