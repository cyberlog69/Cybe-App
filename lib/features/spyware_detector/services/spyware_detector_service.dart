import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../security_logs/services/security_log_service.dart';
import '../models/spyware_scan_report.dart';

class SpywareDetectorService {
  static const MethodChannel _channel = MethodChannel('com.cybe.cybe_app/spyware_detector');

  /// Fetches real-time magnetic flux density (uT) from Magnetometer
  static Future<double> getMagnetometerReading() async {
    if (!Platform.isAndroid) return 45.2; // Ambient baseline
    try {
      final double? reading = await _channel.invokeMethod<double>('getMagnetometerReading');
      return reading ?? 45.0;
    } catch (e) {
      debugPrint('[SpywareDetectorService] Magnetometer error: $e');
      return 45.0;
    }
  }

  /// Scans local Wi-Fi subnet for active IP cameras and RTSP streams
  static Future<List<DetectedIpCam>> scanLanSpyCams() async {
    if (!Platform.isAndroid) {
      return _mockLanCams();
    }

    try {
      final List<dynamic>? rawList = await _channel.invokeMethod('scanLanSpyCams');
      if (rawList == null) return [];

      final List<DetectedIpCam> cams = [];
      for (final item in rawList) {
        final map = Map<String, dynamic>.from(item as Map);
        final ip = map['ip'] as String? ?? '';
        final mac = map['mac'] as String? ?? '';
        final port = (map['port'] as num?)?.toInt() ?? 80;
        final deviceType = map['deviceType'] as String? ?? 'IP Camera';

        cams.add(DetectedIpCam(
          ip: ip,
          mac: mac,
          port: port,
          deviceType: deviceType,
        ));
      }

      if (cams.isNotEmpty) {
        await SecurityLogService.logEvent(
          title: 'Covert IP Camera Detected on Wi-Fi',
          message: 'Found ${cams.length} IP cameras / RTSP streams on local network.',
          severity: 'warning',
          category: 'System',
          rawDetails: cams.map((c) => '${c.ip}:${c.port} (${c.deviceType})').join(', '),
        );
      }

      return cams;
    } catch (e) {
      debugPrint('[SpywareDetectorService] Subnet scan error: $e');
      return [];
    }
  }

  /// Evaluates EMF magnetic risk level
  static String evaluateEmfRisk(double microTesla) {
    if (microTesla >= 140.0) {
      return 'SUSPECTED BUG DETECTED';
    } else if (microTesla >= 80.0) {
      return 'ELEVATED';
    }
    return 'SAFE';
  }

  static List<DetectedIpCam> _mockLanCams() {
    return const [
      DetectedIpCam(
        ip: '192.168.1.112',
        mac: '74:D0:2B:99:A1:02',
        port: 554,
        deviceType: 'RTSP Video Stream (Hikvision/Dahua)',
      ),
      DetectedIpCam(
        ip: '192.168.1.145',
        mac: 'B0:C5:54:12:34:56',
        port: 8080,
        deviceType: 'Wireless Pinhole Spy Cam',
      ),
    ];
  }
}
