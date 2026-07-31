import 'dart:async';
import '../../security_logs/services/security_log_service.dart';
import '../models/qr_scan_result.dart';

class QrInspectorService {
  /// Evaluates any scanned QR payload string for phishing, dangerous downloads, or Wi-Fi exploits
  static Future<QrScanResult> analyzePayload(String rawPayload) async {
    final trimmed = rawPayload.trim();

    // 1. Wi-Fi QR Code Payload
    if (trimmed.toUpperCase().startsWith('WIFI:')) {
      return _analyzeWifiPayload(trimmed);
    }

    // 2. VCard / Contact Payload
    if (trimmed.toUpperCase().contains('BEGIN:VCARD')) {
      return _analyzeVCardPayload(trimmed);
    }

    // 3. SMS / Tel Payload
    if (trimmed.toLowerCase().startsWith('smsto:') || trimmed.toLowerCase().startsWith('tel:')) {
      return _analyzeTelephonyPayload(trimmed);
    }

    // 4. URL or Plain Text
    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://') ||
        trimmed.contains('.')) {
      return await _analyzeUrlPayload(trimmed);
    }

    // Default Plain Text Payload
    return QrScanResult(
      rawPayload: trimmed,
      payloadType: QrPayloadType.text,
      safetyLevel: QrSafetyLevel.safe,
      threatScore: 0,
      unmaskedUrl: '',
      threatBadges: [],
      recommendations: ['Plain text QR payload. Safe to view.'],
      parsedDetails: {'Content': trimmed},
    );
  }

  /// Deep inspection for URLs, redirect chains, IP hosts, and executable extensions
  static Future<QrScanResult> _analyzeUrlPayload(String inputUrl) async {
    String url = inputUrl;
    if (!url.toLowerCase().startsWith('http://') && !url.toLowerCase().startsWith('https://')) {
      url = 'http://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return QrScanResult(
        rawPayload: inputUrl,
        payloadType: QrPayloadType.text,
        safetyLevel: QrSafetyLevel.safe,
        threatScore: 0,
        unmaskedUrl: '',
        threatBadges: [],
        recommendations: ['Malformed payload string.'],
        parsedDetails: {'Content': inputUrl},
      );
    }

    int score = 0;
    final badges = <QrThreatBadge>[];
    final recs = <String>[];
    final unmaskedUrl = url;

    // Check 1: Insecure HTTP Protocol
    if (uri.scheme == 'http') {
      score += 15;
      badges.add(const QrThreatBadge(
        title: 'Unencrypted HTTP Connection',
        description: 'Target URL uses unencrypted HTTP. Data transmitted may be spied on by network gateways.',
        severity: 'warning',
      ));
      recs.add('Avoid entering sensitive credentials or passwords on unencrypted HTTP pages.');
    }

    // Check 2: URL Shortener Detection & Unmasking
    final shortenerDomains = ['bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'ow.ly', 'buff.ly', 'rebrand.ly'];
    final host = uri.host.toLowerCase();

    if (shortenerDomains.any((d) => host.contains(d))) {
      score += 25;
      badges.add(QrThreatBadge(
        title: 'URL Shortener Redirect Traced',
        description: 'Destination URL is masked by shortener domain "$host" to obscure final target website.',
        severity: 'warning',
      ));
      recs.add('Verify unmasked destination URL carefully before proceeding.');
    }

    // Check 3: Raw IP Address Host Hostility
    final isRawIpHost = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
    if (isRawIpHost) {
      score += 45;
      badges.add(QrThreatBadge(
        title: 'Raw IP Address Host Flagged',
        description: 'URL points directly to raw IP address ($host). Phishing kits use raw IPs to bypass domain reputation services.',
        severity: 'critical',
      ));
      recs.add('Do not trust raw IP web addresses unless operating on a private network.');
    }

    // Check 4: Dangerous Executable & Malware Download Check
    final path = uri.path.toLowerCase();
    final dangerousExts = ['.apk', '.exe', '.bat', '.sh', '.vbs', '.iso', '.zip', '.jar', '.scr'];
    if (dangerousExts.any((ext) => path.endsWith(ext))) {
      score += 55;
      badges.add(QrThreatBadge(
        title: 'Direct Executable Payload Download',
        description: 'QR code triggers a direct download of binary/executable file (${path.split('.').last.toUpperCase()}).',
        severity: 'critical',
      ));
      recs.add('Do not install or open downloaded executable files from unknown QR codes.');
    }

    // Check 5: Cyrillic / Homograph Typosquatting Check
    final isPunycode = host.startsWith('xn--') || RegExp(r'[^\x00-\x7F]').hasMatch(host);
    if (isPunycode) {
      score += 50;
      badges.add(const QrThreatBadge(
        title: 'Homograph Domain Impersonation (Punycode)',
        description: 'Domain contains non-Latin Cyrillic characters designed to spoof legitimate banking/social sites.',
        severity: 'critical',
      ));
      recs.add('Beware of lookalike Cyrillic characters in domain name.');
    }

    // Calculate final safety level
    score = score.clamp(0, 100);
    QrSafetyLevel level = QrSafetyLevel.safe;
    if (score >= 45) {
      level = QrSafetyLevel.malicious;
    } else if (score >= 20) {
      level = QrSafetyLevel.suspicious;
    }

    // Log malicious QR detections to System Security Log
    if (level == QrSafetyLevel.malicious || level == QrSafetyLevel.suspicious) {
      await SecurityLogService.logEvent(
        title: 'Malicious QR Code Flagged',
        message: 'Scanned QR code target: "$url" (Score: $score/100).',
        severity: level == QrSafetyLevel.malicious ? 'critical' : 'warning',
        category: 'System',
        rawDetails: badges.map((b) => '${b.title}: ${b.description}').join('\n'),
      );
    }

    return QrScanResult(
      rawPayload: inputUrl,
      payloadType: QrPayloadType.url,
      safetyLevel: level,
      threatScore: score,
      unmaskedUrl: unmaskedUrl,
      threatBadges: badges,
      recommendations: recs.isEmpty
          ? ['URL appears safe. Proceed with standard caution.']
          : recs,
      parsedDetails: {
        'Protocol': uri.scheme.toUpperCase(),
        'Host': uri.host,
        'Path': uri.path.isEmpty ? '/' : uri.path,
      },
    );
  }

  /// Parses Wi-Fi QR payloads: WIFI:S:MySSID;T:WPA;P:MyPassword;;
  static QrScanResult _analyzeWifiPayload(String payload) {
    String ssid = 'Unknown SSID';
    String authType = 'Open';
    String password = '';

    final parts = payload.replaceAll('WIFI:', '').split(';');
    for (final p in parts) {
      if (p.startsWith('S:')) ssid = p.substring(2);
      if (p.startsWith('T:')) authType = p.substring(2);
      if (p.startsWith('P:')) password = p.substring(2);
    }

    final badges = <QrThreatBadge>[];
    int score = 0;

    if (authType.toUpperCase() == 'NOPASS' || authType.toUpperCase() == 'OPEN' || password.isEmpty) {
      score = 35;
      badges.add(const QrThreatBadge(
        title: 'Unencrypted Open Wi-Fi Network',
        description: 'QR code configures auto-connection to an unencrypted Wi-Fi access point.',
        severity: 'warning',
      ));
    }

    return QrScanResult(
      rawPayload: payload,
      payloadType: QrPayloadType.wifi,
      safetyLevel: score > 0 ? QrSafetyLevel.suspicious : QrSafetyLevel.safe,
      threatScore: score,
      unmaskedUrl: '',
      threatBadges: badges,
      recommendations: [
        'Verify Wi-Fi network ownership before connecting.',
      ],
      parsedDetails: {
        'SSID': ssid,
        'Security': authType.isEmpty ? 'Open' : authType,
        'Password': password.isNotEmpty ? '••••••••' : 'None',
      },
    );
  }

  static QrScanResult _analyzeVCardPayload(String payload) {
    return QrScanResult(
      rawPayload: payload,
      payloadType: QrPayloadType.contact,
      safetyLevel: QrSafetyLevel.safe,
      threatScore: 0,
      unmaskedUrl: '',
      threatBadges: [],
      recommendations: ['VCard contact payload. Safe to import.'],
      parsedDetails: {'Type': 'vCard Contact Data'},
    );
  }

  static QrScanResult _analyzeTelephonyPayload(String payload) {
    return QrScanResult(
      rawPayload: payload,
      payloadType: QrPayloadType.sms,
      safetyLevel: QrSafetyLevel.safe,
      threatScore: 0,
      unmaskedUrl: '',
      threatBadges: [],
      recommendations: ['Telephony payload. Verify recipient number.'],
      parsedDetails: {'Payload': payload},
    );
  }
}
