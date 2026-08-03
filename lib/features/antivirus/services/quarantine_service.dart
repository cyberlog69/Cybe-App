import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../../security_logs/services/security_log_service.dart';
import '../models/antivirus_threat.dart';

class QuarantineService {
  static const String _boxName = 'quarantine_box';

  /// Move infected file to Quarantine Vault and register in Hive database
  static Future<bool> quarantineThreat(AntivirusThreat threat) async {
    try {
      final file = File(threat.filePath);
      if (await file.exists()) {
        final quarantineDir = Directory('${file.parent.path}${Platform.pathSeparator}.quarantine');
        if (!await quarantineDir.exists()) {
          await quarantineDir.create(recursive: true);
        }

        final targetPath = '${quarantineDir.path}${Platform.pathSeparator}${threat.fileName}.cybe_quarantine';
        await file.rename(targetPath);

        final box = await Hive.openBox(_boxName);
        final map = threat.toMap();
        map['quarantinedPath'] = targetPath;
        await box.put(threat.id, map);

        await SecurityLogService.logEvent(
          title: 'FILE QUARANTINED: ${threat.fileName}',
          message: 'Threat "${threat.threatName}" isolated to $targetPath.',
          severity: 'safe',
          category: 'Malware',
        );

        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Permanently delete an infected file
  static Future<bool> deleteThreat(AntivirusThreat threat) async {
    try {
      final file = File(threat.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final box = await Hive.openBox(_boxName);
      await box.delete(threat.id);

      await SecurityLogService.logEvent(
        title: 'MALWARE PERMANENTLY DELETED',
        message: 'Infected file "${threat.fileName}" purged from system.',
        severity: 'safe',
        category: 'Malware',
      );

      return true;
    } catch (_) {}
    return false;
  }

  /// Load all quarantined threats
  static Future<List<AntivirusThreat>> loadQuarantinedThreats() async {
    try {
      final box = await Hive.openBox(_boxName);
      return box.values
          .whereType<Map>()
          .map((v) => AntivirusThreat.fromMap(v))
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (_) {
      return [];
    }
  }

  /// Restore quarantined file back to original path
  static Future<bool> restoreThreat(AntivirusThreat threat) async {
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get(threat.id) as Map?;
      if (raw != null) {
        final qPath = raw['quarantinedPath'] as String?;
        if (qPath != null) {
          final qFile = File(qPath);
          if (await qFile.exists()) {
            await qFile.rename(threat.filePath);
          }
        }
        await box.delete(threat.id);

        await SecurityLogService.logEvent(
          title: 'QUARANTINE RESTORED',
          message: 'File "${threat.fileName}" restored to ${threat.filePath}.',
          severity: 'info',
          category: 'Malware',
        );

        return true;
      }
    } catch (_) {}
    return false;
  }
}
