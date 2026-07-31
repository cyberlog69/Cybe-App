class MitmThreatAlert {
  final String title;
  final String description;
  final String severity; // 'critical', 'warning', 'info'
  final DateTime timestamp;
  final String recommendation;

  const MitmThreatAlert({
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    required this.recommendation,
  });
}

class MitmThreatReport {
  final bool isConnected;
  final String ssid;
  final String gatewayIp;
  final String gatewayMac;
  final bool isArpSpoofed;
  final bool isDnsHijacked;
  final bool isSslStripped;
  final bool isCaptivePortalDetected;
  final int threatScore; // 0 to 100 (0 = Clean, 100 = Severe Attack)
  final String threatStatus; // 'SECURE', 'WARNING', 'CRITICAL MITM ATTACK'
  final List<MitmThreatAlert> alerts;
  final Map<String, String> arpCacheTable;

  const MitmThreatReport({
    required this.isConnected,
    required this.ssid,
    required this.gatewayIp,
    required this.gatewayMac,
    required this.isArpSpoofed,
    required this.isDnsHijacked,
    required this.isSslStripped,
    required this.isCaptivePortalDetected,
    required this.threatScore,
    required this.threatStatus,
    required this.alerts,
    required this.arpCacheTable,
  });
}
