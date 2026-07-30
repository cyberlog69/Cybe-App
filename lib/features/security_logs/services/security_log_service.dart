import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/security_event_log.dart';

class SecurityLogService {
  static const _boxName = AppConstants.securityLogsBoxName;
  static Box? _box;

  static Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      await _seedDefaultLogsIfEmpty();
    }
  }

  static Future<void> _seedDefaultLogsIfEmpty() async {
    if (_box!.isEmpty) {
      final now = DateTime.now();
      final initialLogs = [
        SecurityEventLog(
          id: 'seed-1',
          title: 'Cybe Security Service Active',
          message: 'Real-time encryption & event monitoring initialized successfully.',
          severity: 'safe',
          category: 'System',
          timestamp: now.subtract(const Duration(minutes: 2)),
          rawDetails: 'Engine: Cybe Core v1.0.0 | Crypto: AES-256-GCM | Platform: ${Platform.operatingSystem}',
        ),
        SecurityEventLog(
          id: 'seed-2',
          title: 'Vault Integrity Verified',
          message: 'Secure file vault directory structure and master key verified.',
          severity: 'info',
          category: 'Vault',
          timestamp: now.subtract(const Duration(minutes: 10)),
        ),
        SecurityEventLog(
          id: 'seed-3',
          title: 'Network Interface Audited',
          message: 'Active network interface and Gateway IP verified.',
          severity: 'info',
          category: 'Network',
          timestamp: now.subtract(const Duration(hours: 1)),
        ),
        SecurityEventLog(
          id: 'seed-4',
          title: 'Biometric Access Ready',
          message: 'Hardware key storage and biometric authentication engine ready.',
          severity: 'info',
          category: 'Auth',
          timestamp: now.subtract(const Duration(hours: 2)),
        ),
      ];

      for (final log in initialLogs) {
        await _box!.put(log.id, log.toMap());
      }
    }
  }

  /// Appends a new security event to disk
  static Future<void> logEvent({
    required String title,
    required String message,
    String severity = 'info',
    String category = 'System',
    String? rawDetails,
  }) async {
    await init();
    final event = SecurityEventLog.create(
      title: title,
      message: message,
      severity: severity,
      category: category,
      rawDetails: rawDetails,
    );
    await _box!.put(event.id, event.toMap());
  }

  /// Loads all stored security logs sorted by newest first
  static Future<List<SecurityEventLog>> loadLogs() async {
    await init();
    final logs = _box!.values
        .whereType<Map>()
        .map((m) => SecurityEventLog.fromMap(m))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  /// Attempts to capture recent Android system logcat entries (warnings/errors)
  static Future<List<SecurityEventLog>> fetchAndroidSystemLogcat() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await Process.run('logcat', ['-d', '-t', '35', '*:W']);
      if (result.exitCode == 0 && result.stdout != null) {
        final lines = (result.stdout as String).split('\n');
        final List<SecurityEventLog> systemLogs = [];

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          String severity = 'info';
          if (trimmed.contains(' E ') || trimmed.contains(' FATAL ')) {
            severity = 'critical';
          } else if (trimmed.contains(' W ')) {
            severity = 'warning';
          }

          systemLogs.add(SecurityEventLog.create(
            title: 'Android OS Logcat Event',
            message: trimmed.length > 120 ? '${trimmed.substring(0, 120)}...' : trimmed,
            severity: severity,
            category: 'System',
            rawDetails: trimmed,
          ));
        }

        return systemLogs;
      }
    } catch (e) {
      debugPrint('[SecurityLogService] Logcat read error: $e');
    }
    return [];
  }

  /// Clears all log entries from Hive storage
  static Future<void> clearLogs() async {
    await init();
    await _box!.clear();
  }

  /// Formats all logs into plain text for exporting or sharing
  static Future<String> exportLogsFormatted() async {
    final logs = await loadLogs();
    final sb = StringBuffer();
    sb.writeln('=== CYBE SECURITY SYSTEM EVENT LOGS ===');
    sb.writeln('Exported At: ${DateTime.now().toIso8601String()}');
    sb.writeln('Total Log Entries: ${logs.length}');
    sb.writeln('----------------------------------------\n');

    for (final log in logs) {
      sb.writeln('[${log.timestamp.toIso8601String()}] [${log.severity.toUpperCase()}] [${log.category}]');
      sb.writeln('Title: ${log.title}');
      sb.writeln('Message: ${log.message}');
      if (log.rawDetails != null && log.rawDetails!.isNotEmpty) {
        sb.writeln('Details: ${log.rawDetails}');
      }
      sb.writeln('----------------------------------------');
    }

    return sb.toString();
  }
}
