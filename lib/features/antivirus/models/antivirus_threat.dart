class AntivirusThreat {
  final String id;
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final String threatName;
  final String threatCategory; // e.g. Ransomware, Trojan, ReverseShell, EICAR, SuspiciousExtension
  final String threatSeverity; // critical, high, medium, low
  final String signatureMatch;
  final DateTime detectedAt;

  const AntivirusThreat({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.threatName,
    required this.threatCategory,
    required this.threatSeverity,
    required this.signatureMatch,
    required this.detectedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'filePath': filePath,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'threatName': threatName,
        'threatCategory': threatCategory,
        'threatSeverity': threatSeverity,
        'signatureMatch': signatureMatch,
        'detectedAt': detectedAt.toIso8601String(),
      };

  factory AntivirusThreat.fromMap(Map<dynamic, dynamic> map) => AntivirusThreat(
        id: map['id'] as String,
        filePath: map['filePath'] as String,
        fileName: map['fileName'] as String,
        fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
        threatName: map['threatName'] as String,
        threatCategory: map['threatCategory'] as String,
        threatSeverity: map['threatSeverity'] as String,
        signatureMatch: map['signatureMatch'] as String? ?? 'Pattern Match',
        detectedAt: DateTime.tryParse(map['detectedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class ScanProgress {
  final int filesScanned;
  final int threatsFound;
  final String currentFile;
  final double progressPercent;
  final bool isCompleted;

  const ScanProgress({
    required this.filesScanned,
    required this.threatsFound,
    required this.currentFile,
    required this.progressPercent,
    required this.isCompleted,
  });
}
