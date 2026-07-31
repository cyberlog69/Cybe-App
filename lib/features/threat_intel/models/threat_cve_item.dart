enum CveSeverity { critical, high, medium, low }

class ThreatCveItem {
  final String cveId;
  final String vendorName;
  final String productName;
  final String vulnerabilityName;
  final double cvssScore;
  final CveSeverity severity;
  final String description;
  final String requiredAction;
  final String referenceUrl;
  final DateTime publishedDate;
  final bool isKnownExploited;

  const ThreatCveItem({
    required this.cveId,
    required this.vendorName,
    required this.productName,
    required this.vulnerabilityName,
    required this.cvssScore,
    required this.severity,
    required this.description,
    required this.requiredAction,
    required this.referenceUrl,
    required this.publishedDate,
    this.isKnownExploited = true,
  });

  /// Canonical guaranteed working NVD URL
  String get canonicalNvdUrl {
    final cleanId = cveId.trim().toUpperCase();
    if (cleanId.startsWith('CVE-')) {
      return 'https://nvd.nist.gov/vuln/detail/$cleanId';
    }
    return 'https://nvd.nist.gov/vuln/search';
  }

  factory ThreatCveItem.fromJson(Map<String, dynamic> json) {
    final score = (json['cvssScore'] as num?)?.toDouble() ?? 7.5;
    CveSeverity sev = CveSeverity.medium;
    if (score >= 9.0) {
      sev = CveSeverity.critical;
    } else if (score >= 7.0) {
      sev = CveSeverity.high;
    } else if (score >= 4.0) {
      sev = CveSeverity.medium;
    } else {
      sev = CveSeverity.low;
    }

    final id = (json['cveID'] ?? json['cveId'] ?? 'CVE-UNKNOWN').toString().trim();
    
    // Extract first valid http/https URL from notes if present
    String refUrl = '';
    final notesRaw = (json['notes'] ?? json['referenceUrl'] ?? '').toString();
    final urlMatch = RegExp(r'https?://[^\s;,]+').firstMatch(notesRaw);
    if (urlMatch != null) {
      refUrl = urlMatch.group(0)!;
    }
    if (refUrl.isEmpty) {
      refUrl = 'https://nvd.nist.gov/vuln/detail/$id';
    }

    return ThreatCveItem(
      cveId: id,
      vendorName: json['vendorProject'] ?? json['vendorName'] ?? 'Vendor',
      productName: json['product'] ?? json['productName'] ?? 'Software',
      vulnerabilityName: json['vulnerabilityName'] ?? json['shortDescription'] ?? 'Security Vulnerability',
      cvssScore: score,
      severity: sev,
      description: json['shortDescription'] ?? json['description'] ?? 'No description provided.',
      requiredAction: json['requiredAction'] ?? 'Apply vendor security patches immediately.',
      referenceUrl: refUrl,
      publishedDate: DateTime.tryParse(json['dateAdded'] ?? json['publishedDate'] ?? '') ?? DateTime.now(),
      isKnownExploited: json['isKnownExploited'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'cveID': cveId,
        'vendorProject': vendorName,
        'product': productName,
        'vulnerabilityName': vulnerabilityName,
        'cvssScore': cvssScore,
        'shortDescription': description,
        'requiredAction': requiredAction,
        'referenceUrl': referenceUrl,
        'dateAdded': publishedDate.toIso8601String(),
        'isKnownExploited': isKnownExploited,
      };
}
