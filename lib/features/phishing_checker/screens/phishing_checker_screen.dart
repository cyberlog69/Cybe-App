import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';

enum UrlThreatLevel { safe, lowRisk, suspicious, phishing, unknown }

extension UrlThreatExt on UrlThreatLevel {
  Color get color {
    switch (this) {
      case UrlThreatLevel.safe: return AppTheme.safe;
      case UrlThreatLevel.lowRisk: return const Color(0xFF8BC34A);
      case UrlThreatLevel.suspicious: return AppTheme.warning;
      case UrlThreatLevel.phishing: return AppTheme.danger;
      case UrlThreatLevel.unknown: return AppTheme.textSecondary;
    }
  }

  IconData get icon {
    switch (this) {
      case UrlThreatLevel.safe: return Icons.verified_user_outlined;
      case UrlThreatLevel.lowRisk: return Icons.info_outline;
      case UrlThreatLevel.suspicious: return Icons.warning_amber_outlined;
      case UrlThreatLevel.phishing: return Icons.gpp_maybe_outlined;
      case UrlThreatLevel.unknown: return Icons.help_outline;
    }
  }

  String get label {
    switch (this) {
      case UrlThreatLevel.safe: return 'Safe & Verified';
      case UrlThreatLevel.lowRisk: return 'Low Risk Notice';
      case UrlThreatLevel.suspicious: return 'Suspicious URL';
      case UrlThreatLevel.phishing: return 'High Risk / Phishing';
      case UrlThreatLevel.unknown: return 'Unable to Verify';
    }
  }
}

class _CheckFinding {
  final String category;
  final String message;
  final bool isNegative;
  final int scoreImpact;

  _CheckFinding({
    required this.category,
    required this.message,
    required this.isNegative,
    this.scoreImpact = 0,
  });
}

class _CheckResult {
  final String url;
  final String finalHost;
  final int riskScore; // 0 (safe) to 100 (critical threat)
  final UrlThreatLevel threat;
  final List<_CheckFinding> findings;
  final String? redirectedTo;
  final int? statusCode;
  final bool dnsResolved;
  final DateTime checkedAt;

  _CheckResult({
    required this.url,
    required this.finalHost,
    required this.riskScore,
    required this.threat,
    required this.findings,
    this.redirectedTo,
    this.statusCode,
    required this.dnsResolved,
    required this.checkedAt,
  });
}

class PhishingCheckerScreen extends StatefulWidget {
  const PhishingCheckerScreen({super.key});
  @override
  State<PhishingCheckerScreen> createState() => _PhishingCheckerScreenState();
}

class _PhishingCheckerScreenState extends State<PhishingCheckerScreen> {
  final _urlCtrl = TextEditingController();
  bool _checking = false;
  _CheckResult? _result;
  final List<_CheckResult> _history = [];

  static const Map<String, List<String>> _knownBrandDomains = {
    'paypal': ['paypal.com', 'paypal.me', 'paypal-corp.com'],
    'google': ['google.com', 'google.co.uk', 'google.de', 'google.co.in', 'google.fr', 'google.ca', 'google.es', 'google.it', 'google.com.au', 'youtube.com', 'gmail.com', 'googlevideo.com', 'gstatic.com'],
    'microsoft': ['microsoft.com', 'office.com', 'live.com', 'outlook.com', 'windows.com', 'azure.com', 'bing.com', 'visualstudio.com', 'github.com', 'msn.com'],
    'apple': ['apple.com', 'icloud.com', 'itunes.com'],
    'amazon': ['amazon.com', 'amazon.co.uk', 'amazon.de', 'amazon.in', 'amazon.co.jp', 'aws.amazon.com', 'media-amazon.com'],
    'facebook': ['facebook.com', 'fb.com', 'instagram.com', 'whatsapp.com', 'messenger.com', 'meta.com'],
    'netflix': ['netflix.com'],
    'steam': ['steampowered.com', 'steamcommunity.com'],
    'binance': ['binance.com', 'binance.org', 'binance.net'],
    'coinbase': ['coinbase.com'],
  };

  static const List<String> _suspiciousTlds = [
    '.tk', '.ml', '.ga', '.cf', '.gq', '.xyz', '.top', '.click', '.work',
    '.zip', '.mov', '.country', '.kim', '.science', '.party', '.racing', '.surf'
  ];

  static const List<String> _urlShorteners = [
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly', 'tiny.cc', 'is.gd', 'cli.gs',
    'buff.ly', 'adf.ly', 'bit.do', 'cutt.ly', 'rb.gy'
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<_CheckResult> _performComprehensiveCheck(String inputUrl) async {
    var rawUrl = inputUrl.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'https://$rawUrl';
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) {
      return _CheckResult(
        url: inputUrl,
        finalHost: 'Invalid',
        riskScore: 90,
        threat: UrlThreatLevel.phishing,
        findings: [
          _CheckFinding(category: 'Structure', message: 'Malformed URL format or unparseable domain', isNegative: true, scoreImpact: 90)
        ],
        dnsResolved: false,
        checkedAt: DateTime.now(),
      );
    }

    final host = uri.host.toLowerCase();
    final findings = <_CheckFinding>[];
    int score = 0;

    // 1. Check IP address host
    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
      score += 40;
      findings.add(_CheckFinding(
        category: 'Domain Type',
        message: 'Uses raw IP address instead of domain name (common phishing tactic)',
        isNegative: true,
        scoreImpact: 40,
      ));
    }

    // 2. Check Homograph / IDN / Punycode
    if (host.startsWith('xn--')) {
      score += 35;
      findings.add(_CheckFinding(
        category: 'Character Encoding',
        message: 'Punycode / IDN international domain detected — potential homograph spoofing',
        isNegative: true,
        scoreImpact: 35,
      ));
    }

    // 3. Brand Impersonation & Typosquatting Analysis
    for (final entry in _knownBrandDomains.entries) {
      final brand = entry.key;
      final allowedDomains = entry.value;

      if (host.contains(brand)) {
        final isLegit = allowedDomains.any((allowed) => host == allowed || host.endsWith('.$allowed'));
        if (!isLegit) {
          score += 50;
          findings.add(_CheckFinding(
            category: 'Brand Safety',
            message: 'Domain contains "$brand" but does not belong to official $brand domains ($allowedDomains)',
            isNegative: true,
            scoreImpact: 50,
          ));
        } else {
          findings.add(_CheckFinding(
            category: 'Brand Safety',
            message: 'Verified official domain for $brand',
            isNegative: false,
          ));
        }
      }
    }

    // Check for common typosquatting substitutions (e.g. paypa1, goggle, amaz0n)
    final typosquatPatterns = [
      RegExp(r'paypa[1l|i]'),
      RegExp(r'g[0o]{2}g[l1]e'),
      RegExp(r'amaz[0o]n'),
      RegExp(r'micr[0o]s[0o]ft'),
      RegExp(r'faceb[0o]{2}k'),
      RegExp(r'netfl[i1x]x'),
    ];

    for (final p in typosquatPatterns) {
      if (p.hasMatch(host)) {
        final hasBrandMatch = _knownBrandDomains.keys.any((b) => host.contains(b));
        if (!hasBrandMatch) {
          score += 45;
          findings.add(_CheckFinding(
            category: 'Typosquatting',
            message: 'Domain uses character substitution mimicking popular services',
            isNegative: true,
            scoreImpact: 45,
          ));
          break;
        }
      }
    }

    // 4. TLD Risk Check
    for (final tld in _suspiciousTlds) {
      if (host.endsWith(tld)) {
        score += 25;
        findings.add(_CheckFinding(
          category: 'Domain TLD',
          message: 'Top-Level Domain "$tld" has a high statistical correlation with spam & phishing',
          isNegative: true,
          scoreImpact: 25,
        ));
        break;
      }
    }

    // 5. Subdomain Abstraction
    final parts = host.split('.');
    if (parts.length > 4) {
      score += 20;
      findings.add(_CheckFinding(
        category: 'URL Structure',
        message: 'Excessive subdomain depth (${parts.length - 2} levels) used to mask real domain',
        isNegative: true,
        scoreImpact: 20,
      ));
    }

    // 6. URL Shortener Check
    if (_urlShorteners.any((s) => host == s || host.endsWith('.$s'))) {
      score += 15;
      findings.add(_CheckFinding(
        category: 'Obfuscation',
        message: 'URL shortener service hides final destination target',
        isNegative: true,
        scoreImpact: 15,
      ));
    }

    // 7. Embedded @ Symbol Trick
    if (rawUrl.contains('@')) {
      score += 55;
      findings.add(_CheckFinding(
        category: 'URL Structure',
        message: 'Embedded "@" sign forces browser credential override (classic phishing trick)',
        isNegative: true,
        scoreImpact: 55,
      ));
    }

    // 8. Scheme Check (HTTPS vs HTTP)
    if (uri.scheme == 'http') {
      score += 15;
      findings.add(_CheckFinding(
        category: 'Encryption',
        message: 'Plaintext HTTP connection — traffic is not encrypted with SSL/TLS',
        isNegative: true,
        scoreImpact: 15,
      ));
    } else if (uri.scheme == 'https') {
      findings.add(_CheckFinding(
        category: 'Encryption',
        message: 'HTTPS encrypted connection protocol in use',
        isNegative: false,
      ));
    }

    // 9. Excessive Hyphens / Obfuscation length
    final dashCount = '-'.allMatches(host).length;
    if (dashCount >= 3) {
      score += 15;
      findings.add(_CheckFinding(
        category: 'Domain Pattern',
        message: 'Multiple hyphens ($dashCount) in hostname commonly seen in fake portal URLs',
        isNegative: true,
        scoreImpact: 15,
      ));
    }

    if (rawUrl.length > 150) {
      score += 15;
      findings.add(_CheckFinding(
        category: 'URL Length',
        message: 'Excessive URL length (${rawUrl.length} characters) may contain hidden query tokens',
        isNegative: true,
        scoreImpact: 15,
      ));
    }

    // 10. Live DNS & HTTP Probe
    bool dnsResolved = false;
    String? redirectedUrl;
    int? httpCode;

    try {
      final lookup = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      if (lookup.isNotEmpty && lookup.any((a) => a.address.isNotEmpty)) {
        dnsResolved = true;
        findings.add(_CheckFinding(
          category: 'DNS Resolution',
          message: 'Domain active & resolved to IP: ${lookup.first.address}',
          isNegative: false,
        ));
      }
    } catch (_) {
      dnsResolved = false;
      score += 30;
      findings.add(_CheckFinding(
        category: 'DNS Resolution',
        message: 'DNS lookup failed — domain does not exist or host is offline',
        isNegative: true,
        scoreImpact: 30,
      ));
    }

    if (dnsResolved) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final req = await client.getUrl(uri);
        req.followRedirects = false;
        final res = await req.close();
        httpCode = res.statusCode;

        if (res.isRedirect && res.headers['location'] != null) {
          redirectedUrl = res.headers['location']!.first;
          score += 15;
          findings.add(_CheckFinding(
            category: 'Redirection',
            message: 'URL performs automatic HTTP ${res.statusCode} redirect to: $redirectedUrl',
            isNegative: true,
            scoreImpact: 15,
          ));
        } else {
          findings.add(_CheckFinding(
            category: 'HTTP Status',
            message: 'Server responded with HTTP status $httpCode',
            isNegative: false,
          ));
        }
        client.close();
      } catch (e) {
        debugPrint('HTTP probe skipped: $e');
      }
    }

    if (findings.every((f) => !f.isNegative)) {
      findings.add(_CheckFinding(
        category: 'Safety Summary',
        message: 'No structural, brand, or network risk anomalies detected',
        isNegative: false,
      ));
    }

    // Determine final threat level from calculated risk score
    final finalScore = score.clamp(0, 100);
    UrlThreatLevel threatLevel;
    if (finalScore <= 20) {
      threatLevel = UrlThreatLevel.safe;
    } else if (finalScore <= 40) {
      threatLevel = UrlThreatLevel.lowRisk;
    } else if (finalScore <= 70) {
      threatLevel = UrlThreatLevel.suspicious;
    } else {
      threatLevel = UrlThreatLevel.phishing;
    }

    return _CheckResult(
      url: inputUrl,
      finalHost: host,
      riskScore: finalScore,
      threat: threatLevel,
      findings: findings,
      redirectedTo: redirectedUrl,
      statusCode: httpCode,
      dnsResolved: dnsResolved,
      checkedAt: DateTime.now(),
    );
  }

  Future<void> _checkUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _checking = true; _result = null; });

    final result = await _performComprehensiveCheck(url);
    if (mounted) {
      setState(() {
        _result = result;
        _checking = false;
      });
      _history.insert(0, result);
    }
  }

  Future<void> _scanQrCode(BuildContext context) async {
    final scannedUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: 480,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Scan URL QR Code', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Point camera at a website or link QR code', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final raw = barcode.rawValue;
                      if (raw != null && (raw.startsWith('http://') || raw.startsWith('https://') || raw.contains('.'))) {
                        Navigator.pop(sheetCtx, raw);
                        break;
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => Navigator.pop(sheetCtx),
              icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              label: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (scannedUrl != null && scannedUrl.isNotEmpty && mounted) {
      _urlCtrl.text = scannedUrl;
      _checkUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phishing URL Checker'), backgroundColor: AppTheme.background),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Input card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E1E30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analyze URL for Phishing & Malicious Patterns',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'e.g. https://example.com or paste link...',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      onSubmitted: (_) => _checkUrl(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _checking ? null : _checkUrl,
                              icon: _checking
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Icon(Icons.security_outlined),
                              label: Text(_checking ? 'Analyzing URL...' : 'Check URL Security'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              _urlCtrl.text = data!.text!;
                            }
                          },
                          icon: const Icon(Icons.paste, color: AppTheme.primary),
                          tooltip: 'Paste from clipboard',
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () => _scanQrCode(context),
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
                          tooltip: 'Scan QR Code URL',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Result card
              if (_result != null) _buildResult(_result!),

              // History
              if (_history.length > 1) ...[
                const SizedBox(height: 20),
                const Text('Recent URL Checks', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                ..._history.skip(1).take(5).map(_buildHistoryItem),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(_CheckResult r) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r.threat.color.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: r.threat.color.withOpacity(0.12), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.threat.color.withOpacity(0.15),
                ),
                child: Icon(r.threat.icon, color: r.threat.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.threat.label, style: TextStyle(color: r.threat.color, fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(r.url, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: r.threat.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: r.threat.color.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text('${r.riskScore}', style: TextStyle(color: r.threat.color, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('RISK SCORE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Risk Meter Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (r.riskScore / 100).clamp(0.02, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF1E1E30),
              valueColor: AlwaysStoppedAnimation<Color>(r.threat.color),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1E1E30)),
          const SizedBox(height: 12),

          const Text('Security Analysis Findings', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          ...r.findings.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: f.isNegative ? AppTheme.warning.withOpacity(0.2) : AppTheme.safe.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  f.isNegative ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  color: f.isNegative ? (f.scoreImpact >= 40 ? AppTheme.danger : AppTheme.warning) : AppTheme.safe,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.category, style: TextStyle(
                        color: f.isNegative ? AppTheme.warning : AppTheme.safe,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                      const SizedBox(height: 2),
                      Text(f.message, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
                if (f.isNegative && f.scoreImpact > 0)
                  Text('+${f.scoreImpact}', style: const TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(_CheckResult r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Row(
        children: [
          Icon(r.threat.icon, color: r.threat.color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(r.url, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: r.threat.color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text('Score: ${r.riskScore}', style: TextStyle(color: r.threat.color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
