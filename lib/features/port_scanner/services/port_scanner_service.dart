import 'dart:async';
import 'dart:io';

enum PortRiskLevel { safe, warning, danger }

class PortScanResult {
  final int port;
  final String serviceName;
  final bool isOpen;
  final int latencyMs;
  final PortRiskLevel risk;
  final String description;

  const PortScanResult({
    required this.port,
    required this.serviceName,
    required this.isOpen,
    required this.latencyMs,
    required this.risk,
    required this.description,
  });
}

class PortScannerService {
  static const Map<int, Map<String, dynamic>> commonPorts = {
    21: {'name': 'FTP', 'risk': PortRiskLevel.warning, 'desc': 'File Transfer Protocol (Unencrypted plaintext credentials)'},
    22: {'name': 'SSH', 'risk': PortRiskLevel.safe, 'desc': 'Secure Shell Remote Access'},
    23: {'name': 'Telnet', 'risk': PortRiskLevel.danger, 'desc': 'CRITICAL: Unencrypted remote terminal! Highly vulnerable to sniffing.'},
    25: {'name': 'SMTP', 'risk': PortRiskLevel.warning, 'desc': 'Simple Mail Transfer Protocol'},
    53: {'name': 'DNS', 'risk': PortRiskLevel.safe, 'desc': 'Domain Name System Service'},
    80: {'name': 'HTTP', 'risk': PortRiskLevel.warning, 'desc': 'Unencrypted Web Server'},
    110: {'name': 'POP3', 'risk': PortRiskLevel.warning, 'desc': 'Post Office Protocol'},
    143: {'name': 'IMAP', 'risk': PortRiskLevel.warning, 'desc': 'Internet Message Access Protocol'},
    443: {'name': 'HTTPS', 'risk': PortRiskLevel.safe, 'desc': 'TLS Encrypted Web Server'},
    445: {'name': 'SMB', 'risk': PortRiskLevel.danger, 'desc': 'HIGH RISK: Server Message Block (Target for WannaCry/EternalBlue exploits)'},
    1433: {'name': 'MSSQL', 'risk': PortRiskLevel.warning, 'desc': 'Microsoft SQL Server Database'},
    1900: {'name': 'UPnP', 'risk': PortRiskLevel.danger, 'desc': 'CRITICAL: Universal Plug and Play (Frequently exploited by IoT malware)'},
    3306: {'name': 'MySQL', 'risk': PortRiskLevel.warning, 'desc': 'MySQL Database Service'},
    3389: {'name': 'RDP', 'risk': PortRiskLevel.warning, 'desc': 'Remote Desktop Protocol'},
    5432: {'name': 'PostgreSQL', 'risk': PortRiskLevel.warning, 'desc': 'PostgreSQL Database Service'},
    8080: {'name': 'Alt-HTTP', 'risk': PortRiskLevel.warning, 'desc': 'Alternative Web Proxy Server'},
  };

  static Future<List<PortScanResult>> scanHost(String host, {Duration timeout = const Duration(milliseconds: 1200)}) async {
    final results = <PortScanResult>[];

    for (final entry in commonPorts.entries) {
      final port = entry.key;
      final info = entry.value;

      final sw = Stopwatch()..start();
      var isOpen = false;

      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        sw.stop();
        isOpen = true;
        await socket.close();
      } catch (_) {
        sw.stop();
        isOpen = false;
      }

      if (isOpen) {
        results.add(PortScanResult(
          port: port,
          serviceName: info['name'] as String,
          isOpen: true,
          latencyMs: sw.elapsedMilliseconds,
          risk: info['risk'] as PortRiskLevel,
          description: info['desc'] as String,
        ));
      }
    }

    return results;
  }
}
