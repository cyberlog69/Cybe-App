enum QrPayloadType { url, wifi, text, contact, sms, phone }
enum QrSafetyLevel { safe, suspicious, malicious }

class QrThreatBadge {
  final String title;
  final String description;
  final String severity; // 'critical', 'warning', 'info'

  const QrThreatBadge({
    required this.title,
    required this.description,
    required this.severity,
  });
}

class QrScanResult {
  final String rawPayload;
  final QrPayloadType payloadType;
  final QrSafetyLevel safetyLevel;
  final int threatScore; // 0 to 100
  final String unmaskedUrl;
  final List<QrThreatBadge> threatBadges;
  final List<String> recommendations;
  final Map<String, String> parsedDetails;

  const QrScanResult({
    required this.rawPayload,
    required this.payloadType,
    required this.safetyLevel,
    required this.threatScore,
    required this.unmaskedUrl,
    required this.threatBadges,
    required this.recommendations,
    required this.parsedDetails,
  });
}
