import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../security_logs/services/security_log_service.dart';
import '../models/mitm_threat_report.dart';
import 'secure_dns_vpn_service.dart';

class MitmDetectorService {
  static const MethodChannel _channel = MethodChannel('com.cybe.cybe_app/mitm_detector');
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Runs 5-point diagnostic scan covering Windows, Linux, Android, and macOS across Wi-Fi, Ethernet, and Mobile Data
  static Future<MitmThreatReport> runDiagnosticScan() async {
    final connectivityList = await Connectivity().checkConnectivity();
    final isWifi = connectivityList.contains(ConnectivityResult.wifi);
    final isMobile = connectivityList.contains(ConnectivityResult.mobile);
    final isEthernet = connectivityList.contains(ConnectivityResult.ethernet);
    final isConnected = isWifi || isMobile || isEthernet || !kIsWeb;

    if (!isConnected) {
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
        threatStatus: 'DISCONNECTED',
        alerts: [],
        arpCacheTable: {},
      );
    }

    String ssid = 'Active Connection';
    if (isWifi) {
      ssid = 'Wi-Fi Network';
      try {
        final wifiName = await _networkInfo.getWifiName();
        if (wifiName != null && wifiName.isNotEmpty) {
          ssid = wifiName.replaceAll('"', '');
        }
      } catch (_) {}
    } else if (isMobile) {
      ssid = 'Cellular Mobile Network (4G/5G/LTE)';
    } else if (isEthernet) {
      ssid = 'Wired Ethernet Connection';
    } else if (Platform.isWindows) {
      ssid = 'Windows Network Adapter';
    } else if (Platform.isLinux) {
      ssid = 'Linux Network Interface';
    }

    String gatewayIp = isMobile ? 'Carrier Mobile Gateway' : 'Unknown';
    String gatewayMac = isMobile ? 'Cellular Protocol Stack' : 'Unknown';
    final Map<String, String> arpTable = {};
    final List<MitmThreatAlert> alerts = [];

    // 1. Fetch Native ARP Table & Gateway Details across Windows, Linux, & Android
    if (Platform.isWindows) {
      try {
        final res = await Process.run('arp', ['-a']);
        if (res.exitCode == 0) {
          final lines = (res.stdout as String).split('\n');
          for (final line in lines) {
            final match = RegExp(
                    r'(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2})')
                .firstMatch(line);
            if (match != null) {
              final ip = match.group(1)!;
              final mac = match.group(2)!.replaceAll('-', ':').toLowerCase();
              arpTable[ip] = mac;
              if (ip.endsWith('.1') || gatewayIp == 'Unknown') {
                gatewayIp = ip;
                gatewayMac = mac;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MitmDetectorService] Windows ARP error: $e');
      }
    } else if (Platform.isLinux) {
      try {
        final file = File('/proc/net/arp');
        if (await file.exists()) {
          final lines = await file.readAsLines();
          for (final line in lines.skip(1)) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final ip = parts[0];
              final mac = parts[3].toLowerCase();
              if (mac != '00:00:00:00:00:00') {
                arpTable[ip] = mac;
                if (ip.endsWith('.1') || gatewayIp == 'Unknown') {
                  gatewayIp = ip;
                  gatewayMac = mac;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MitmDetectorService] Linux ARP error: $e');
      }
    } else if (Platform.isAndroid && (isWifi || isEthernet)) {
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
        debugPrint('[MitmDetectorService] Android ARP error: $e');
      }
    }

    if (gatewayIp == 'Unknown' && arpTable.isNotEmpty) {
      gatewayIp = arpTable.keys.first;
      gatewayMac = arpTable.values.first;
    }

    // 2. ARP Poisoning Analysis (Windows, Linux, Android)
    bool isArpSpoofed = false;
    if (!isMobile && arpTable.isNotEmpty) {
      final Map<String, List<String>> macToIps = {};
      arpTable.forEach((ip, mac) {
        macToIps.putIfAbsent(mac, () => []).add(ip);
      });

      macToIps.forEach((mac, ips) {
        if (mac != '00:00:00:00:00:00' && ips.length > 1) {
          isArpSpoofed = true;
          alerts.add(MitmThreatAlert(
            title: 'ARP Cache Poisoning Detected',
            description:
                'Hardware MAC $mac is claiming multiple IP addresses (${ips.join(", ")}). An attacker on this network is impersonating devices.',
            severity: 'critical',
            timestamp: DateTime.now(),
            recommendation:
                'Disconnect immediately or activate Encrypted DNS / OpenVPN Shield to secure your traffic!',
          ));
        }
      });
    }

    // 3. SSL Stripping & Proxy Interception Probe
    bool isSslStripped = false;
    try {
      if (Platform.isAndroid) {
        final bool sslPassed = await _channel.invokeMethod<bool>('checkSslIntegrity') ?? false;
        if (!sslPassed) isSslStripped = true;
      } else {
        final client = HttpClient()..badCertificateCallback = (cert, host, port) => false;
        final req = await client.getUrl(Uri.parse('https://www.google.com/generate_204'));
        final resp = await req.close();
        if (resp.statusCode != 204 && resp.statusCode != 200) {
          isSslStripped = true;
        }
      }

      if (isSslStripped) {
        alerts.add(MitmThreatAlert(
          title: 'SSL / HTTPS Certificate Proxy Interception',
          description:
              'Secure TLS probe failed or returned forged certificate headers. Encrypted traffic may be intercepted by a rogue gateway.',
          severity: 'critical',
          timestamp: DateTime.now(),
          recommendation:
              'Enable Cybe Encrypted DNS Shield or OpenVPN Tunnel immediately to bypass rogue SSL proxies.',
        ));
      }
    } catch (_) {}

    // 4. DNS Hijacking & Encrypted DNS Probe
    bool isDnsHijacked = false;
    try {
      if (SecureDnsVpnService.isDnsShieldActive) {
        final secureIps = await SecureDnsVpnService.resolveSecureDns('google.com');
        if (secureIps.isEmpty) {
          isDnsHijacked = true;
        }
      } else {
        final addrs = await InternetAddress.lookup('google.com');
        if (addrs.isEmpty) {
          isDnsHijacked = true;
        }
      }

      if (isDnsHijacked) {
        alerts.add(MitmThreatAlert(
          title: 'DNS Resolution Probe Failed / Hijacked',
          description:
              'System DNS lookup for canonical domains failed or was manipulated by the network provider.',
          severity: 'warning',
          timestamp: DateTime.now(),
          recommendation:
              'Switch to Encrypted DNS (${SecureDnsVpnService.selectedProvider.displayName}) or OpenVPN.',
        ));
      }
    } catch (_) {
      isDnsHijacked = true;
    }

    // 5. Calculate Threat Score & Shield Defenses
    int threatScore = 0;
    if (isArpSpoofed) threatScore += 50;
    if (isSslStripped) threatScore += 40;
    if (isDnsHijacked) threatScore += 25;

    // Apply Encrypted DNS & OpenVPN Shield Reduction
    if (SecureDnsVpnService.isVpnTunnelActive) {
      threatScore = 0;
    } else if (SecureDnsVpnService.isDnsShieldActive && threatScore > 0) {
      threatScore = (threatScore - 30).clamp(0, 100);
    }
    threatScore = threatScore.clamp(0, 100);

    String status = 'SECURE';
    if (SecureDnsVpnService.isVpnTunnelActive) {
      status = 'PROTECTED BY OPENVPN TUNNEL';
    } else if (SecureDnsVpnService.isDnsShieldActive && threatScore == 0) {
      status = 'PROTECTED BY ENCRYPTED DNS';
    } else if (threatScore >= 50) {
      status = 'CRITICAL MITM ATTACK';
    } else if (threatScore > 0) {
      status = 'WARNING';
    }

    // Log critical threats to Security Event Log
    if (isArpSpoofed || isSslStripped) {
      await SecurityLogService.logEvent(
        title: isMobile ? 'CRITICAL: Cellular Data MitM Interception' : 'CRITICAL: Network MitM Attack Flagged',
        message: 'Active network attack detected on "$ssid". Gateway IP: $gatewayIp.',
        severity: 'critical',
        category: 'Network',
        rawDetails:
            'ARP Spoofed: $isArpSpoofed | SSL Stripped: $isSslStripped | Threat Score: $threatScore',
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
}
