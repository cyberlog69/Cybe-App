import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';

enum UrlThreatLevel { safe, suspicious, phishing, malware, unknown }

extension UrlThreatExt on UrlThreatLevel {
  Color get color {
    switch (this) {
      case UrlThreatLevel.safe: return AppTheme.safe;
      case UrlThreatLevel.suspicious: return AppTheme.warning;
      case UrlThreatLevel.phishing: return AppTheme.danger;
      case UrlThreatLevel.malware: return AppTheme.danger;
      case UrlThreatLevel.unknown: return AppTheme.textSecondary;
    }
  }
  IconData get icon {
    switch (this) {
      case UrlThreatLevel.safe: return Icons.verified_user_outlined;
      case UrlThreatLevel.suspicious: return Icons.warning_amber_outlined;
      case UrlThreatLevel.phishing: return Icons.phishing;
      case UrlThreatLevel.malware: return Icons.bug_report_outlined;
      case UrlThreatLevel.unknown: return Icons.help_outline;
    }
  }
  String get label {
    switch (this) {
      case UrlThreatLevel.safe: return 'Safe';
      case UrlThreatLevel.suspicious: return 'Suspicious';
      case UrlThreatLevel.phishing: return 'Phishing Site';
      case UrlThreatLevel.malware: return 'Malware Detected';
      case UrlThreatLevel.unknown: return 'Unknown';
    }
  }
}

class _CheckResult {
  final String url;
  final UrlThreatLevel threat;
  final List<String> findings;
  final DateTime checkedAt;
  _CheckResult({required this.url, required this.threat, required this.findings, required this.checkedAt});
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

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  /// Heuristic analysis (no API key needed)
  _CheckResult _heuristicCheck(String url) {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    final findings = <String>[];
    var threat = UrlThreatLevel.safe;

    if (uri == null) {
      return _CheckResult(url: url, threat: UrlThreatLevel.unknown, findings: ['Invalid URL format'], checkedAt: DateTime.now());
    }

    final host = uri.host.toLowerCase();

    // Check for IP address instead of domain
    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
      findings.add('⚠ Uses IP address instead of domain name (common phishing tactic)');
      threat = UrlThreatLevel.suspicious;
    }

    // Check for suspicious TLDs
    final suspiciousTlds = ['.tk', '.ml', '.ga', '.cf', '.gq', '.xyz', '.top', '.click', '.work'];
    for (final tld in suspiciousTlds) {
      if (host.endsWith(tld)) {
        findings.add('⚠ Suspicious top-level domain: $tld');
        if (threat == UrlThreatLevel.safe) threat = UrlThreatLevel.suspicious;
      }
    }

    // Check for lookalike domains (brand confusion)
    final brands = ['paypal', 'google', 'facebook', 'apple', 'amazon', 'microsoft', 'netflix', 'instagram', 'bank'];
    for (final brand in brands) {
      if (host.contains(brand) && !host.endsWith('$brand.com') && !host.endsWith('$brand.co')) {
        findings.add('⚠ Domain may be impersonating "$brand"');
        threat = UrlThreatLevel.phishing;
      }
    }

    // Check for excessive subdomains
    final subdomains = host.split('.').length - 2;
    if (subdomains > 3) {
      findings.add('⚠ Suspicious: $subdomains subdomain levels (unusual for legitimate sites)');
      if (threat == UrlThreatLevel.safe) threat = UrlThreatLevel.suspicious;
    }

    // Check for URL shorteners
    final shorteners = ['bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly', 'tiny.cc', 'is.gd', 'cli.gs'];
    if (shorteners.any((s) => host == s || host.endsWith('.$s'))) {
      findings.add('⚠ URL shortener detected — destination may be hidden');
      if (threat == UrlThreatLevel.safe) threat = UrlThreatLevel.suspicious;
    }

    // Check for @ symbol in URL (phishing trick)
    if (url.contains('@')) {
      findings.add('⚠ Contains "@" symbol — a classic phishing URL trick');
      threat = UrlThreatLevel.phishing;
    }

    // Check for non-HTTPS
    if (uri.scheme == 'http') {
      findings.add('ℹ Not using HTTPS — connection is unencrypted');
      if (threat == UrlThreatLevel.safe) threat = UrlThreatLevel.suspicious;
    }

    // Check for very long URL
    if (url.length > 200) {
      findings.add('⚠ Unusually long URL (${url.length} chars) — may contain obfuscation');
      if (threat == UrlThreatLevel.safe) threat = UrlThreatLevel.suspicious;
    }

    // Check for multiple dashes in domain
    if (host.split('-').length > 4) {
      findings.add('⚠ Excessive hyphens in domain — uncommon for legitimate sites');
      if (threat == UrlThreatLevel.safe) threat = UrlThreatLevel.suspicious;
    }

    if (findings.isEmpty) {
      findings.add('✓ No suspicious patterns detected');
    }

    return _CheckResult(url: url, threat: threat, findings: findings, checkedAt: DateTime.now());
  }

  Future<void> _checkUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _checking = true; _result = null; });

    // First do heuristic check
    final heuristic = _heuristicCheck(url);
    setState(() { _result = heuristic; _checking = false; });
    _history.insert(0, heuristic);
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
                  const Text('Check a URL', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'https://example.com or paste any URL',
                      prefixIcon: Icon(Icons.link),
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
                            label: Text(_checking ? 'Checking...' : 'Check URL'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
              const Text('Recent Checks', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
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
        border: Border.all(color: r.threat.color.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: r.threat.color.withOpacity(0.1), blurRadius: 20)],
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
                    Text(r.threat.label, style: TextStyle(color: r.threat.color, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(r.url, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1E1E30)),
          const SizedBox(height: 12),
          const Text('Analysis', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...r.findings.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(f, style: TextStyle(color: f.startsWith('✓') ? AppTheme.safe : AppTheme.textPrimary, fontSize: 13)),
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
          Text(r.threat.label, style: TextStyle(color: r.threat.color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
