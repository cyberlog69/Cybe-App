import 'package:uuid/uuid.dart';

class SecurityEventLog {
  final String id;
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'critical', 'safe'
  final String category; // 'System', 'Vault', 'Auth', 'Network', 'USB', 'BLE'
  final DateTime timestamp;
  final String? rawDetails;

  const SecurityEventLog({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.category = 'System',
    required this.timestamp,
    this.rawDetails,
  });

  factory SecurityEventLog.create({
    required String title,
    required String message,
    String severity = 'info',
    String category = 'System',
    String? rawDetails,
  }) {
    return SecurityEventLog(
      id: const Uuid().v4(),
      title: title,
      message: message,
      severity: severity,
      category: category,
      timestamp: DateTime.now(),
      rawDetails: rawDetails,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'severity': severity,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'rawDetails': rawDetails ?? '',
      };

  factory SecurityEventLog.fromMap(Map<dynamic, dynamic> map) => SecurityEventLog(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Event',
        message: map['message'] as String? ?? '',
        severity: map['severity'] as String? ?? 'info',
        category: map['category'] as String? ?? 'System',
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'] as String)
            : DateTime.now(),
        rawDetails: map['rawDetails'] as String?,
      );
}
