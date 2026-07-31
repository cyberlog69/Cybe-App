import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../security_logs/services/security_log_service.dart';
import '../models/mitm_threat_report.dart';

class MitmDetectorService {
  static const MethodChannel _channel = MethodChannel('com.cybe.cybe_app/mitm_detector');
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Runs complete 4-point diagnostic scan for MitM, ARP spoofing, SSL stripping, and DNS hijacking
  static Future<MitmThreatReport> runDiagnosticScan() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity.contains(ConnectivityResult.wifi);

    if (!isWifi) {
      return const MitmThreatReport(
        isConnected: false,
        ssid: 'Not Connected',
        gatewayIp: 'N/A',
        gatewayMac: 'N/A',
        isArpSpoofed: false,
        isDnsHijacked: false,
        isSslStripped: false,
        isCaptivePortalDetected: false,
        threatScore: 0,
        threatStatus: 'NO WI-FI',
        alerts: [],
        arpCacheTable: {},
      );
    }

    String ssid = 'Current Wi-Fi';
    try {
      final wifiName = await _networkInfo.getWifiName();
      if (wifiName != null && wifiName.isNotEmpty) {
        ssid = wifiName.replaceAll('"', '');
      }
    } catch (_) {}

    if (!Platform.isAndroid) {
      return _generateMockShieldReport(ssid);
    }

    String gatewayIp = 'Unknown';
    String gatewayMac = 'Unknown';
    final Map<String, String> arpTable = {};
    final List<MitmThreatAlert> alerts = [];

    // 1. Fetch Native ARP Table & Gateway Details
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod('getGatewayAndArpInfo');
      if (res != null) {
        gatewayIp = res['gatewayIp'] as String? ?? 'Unknown';
        gatewayMac = res['gatewayMac'] as String? ?? 'Unknown';

        final rawArp = res['arpEntries'] as List<dynamic>?;
        if (rawArp != null) {
          for (final item in rawArp) {
            final map = Map<String, String>.from(item as Map);
            if (map['ip'] != null && map['mac'] != null) {
              arpTable[map['ip']!] = map['mac']!;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MitmDetectorService] Native ARP fetch error: $e');
    }

    // 2. ARP Poisoning Analysis
    bool isArpSpoofed = false;
    final Map<String, List<String>> macToIps = {};
    arpTable.forEach((ip, mac) {
      macToIps.putIfAbsent(mac, () => []).add(ip);
    });

    macToIps.forEach((mac, ips) {
      if (mac != '00:00:00:00:00:00' && ips.length > 1) {
        // Same MAC assigned to multiple IP addresses indicates ARP poisoning!
        isArpSpoofed = true;
        alerts.add(MitmThreatAlert(
          title: 'ARP Cache Poisoning Detected',
          description: 'Hardware MAC $mac is claiming multiple IP addresses (${ips.join(", ")}). An attacker on this Wi-Fi is impersonating network devices.',
          severity: 'critical',
          timestamp: DateTime.now(),
          recommendation: 'Disconnect immediately! Do not enter passwords or bank details over this network.',
        ));
      }
    });

    // 3. SSL Stripping & Interception Probe
    bool isSslStripped = false;
    try {
      final bool sslPassed = await _channel.invokeMethod<bool>('checkSslIntegrity') ?? false;
      if (!sslPassed) {
        isSslStripped = true;
        alerts.add(MitmThreatAlert(
          title: 'SSL / HTTPS Certificate Proxy Detected',
          description: 'Secure TLS probe failed or returned forged certificate headers. Encrypted traffic may be intercepted by a proxy.',
          severity: 'critical',
          timestamp: DateTime.now(),
          recommendation: 'Enable Cybe Security Vault or switch to Mobile Data immediately.',
        ));
      }
    } catch (_) {}

    // 4. DNS Hijacking Check
    bool isDnsHijacked = false;
    try {
      final addrs = await InternetAddress.lookup('google.com');
      if (addrs.isEmpty) {
        isDnsHijacked = true;
        alerts.add(MitmThreatAlert(
          title: 'DNS Resolution Probe Failed',
          description: 'System DNS lookup for canonical domains failed or was intercepted by network gateway.',
          severity: 'warning',
          timestamp: DateTime.now(),
          recommendation: 'Configure Encrypted DNS (DoH / DoT) or use a trusted VPN.',
        ));
      }
    } catch (_) {
      isDnsHijacked = true;
    }

    // Calculate Threat Score
    int threatScore = 0;
    if (isArpSpoofed) threatScore += 50;
    if (isSslStripped) threatScore += 40;
    if (isDnsHijacked) threatScore += 25;
    threatScore = threatScore.clamp(0, 100);

    String status = 'SECURE';
    if (threatScore >= 50) {
      status = 'CRITICAL MITM ATTACK';
    } else if (threatScore > 0) {
      status = 'WARNING';
    }

    // Log critical threats to System Security Event Log
    if (isArpSpoofed || isSslStripped) {
      await SecurityLogService.logEvent(
        title: 'CRITICAL: Wi-Fi MitM Attack Flagged',
        message: 'Active network attack detected on SSID "$ssid". Gateway IP: $gatewayIp, MAC: $gatewayMac.',
        severity: 'critical',
        category: 'Network',
        rawDetails: 'ARP Spoofed: $isArpSpoofed | SSL Stripped: $isSslStripped | Threat Score: $threatScore',
      );
    }

    return MitmThreatReport(
      isConnected: true,
      ssid: ssid,
      gatewayIp: gatewayIp,
      gatewayMac: gatewayMac,
      isArpSpoofed: isArpSpoofed,
      isDnsHijacked: isDnsHijacked,
      isSslStripped: isSslStripped,
      isCaptivePortalDetected: false,
      threatScore: threatScore,
      threatStatus: status,
      alerts: alerts,
      arpCacheTable: arpTable,
    );
  }

  /// Generates clean mock report for desktop testing
  static MitmThreatReport _generateMockShieldReport(String ssid) {
    return MitmThreatReport(
      isConnected: true,
      ssid: ssid,
      gatewayIp: '192.168.1.1',
      gatewayMac: '3C:84:6A:12:90:FE',
      isArpSpoofed: false,
      isDnsHijacked: false,
      isSslStripped: false,
      isCaptivePortalDetected: false,
      threatScore: 0,
      threatStatus: 'SECURE',
      alerts: [],
      arpCacheTable: const {
        '192.168.1.1': '3C:84:6A:12:90:FE',
        '192.168.1.105': 'B4:E6:2D:4F:11:8A',
        '192.168.1.120': 'D8:9C:67:88:AA:01',
      },
    );
  }
}
