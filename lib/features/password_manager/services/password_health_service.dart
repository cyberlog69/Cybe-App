import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/password_entry.dart';

class PasswordHealthIssue {
  final PasswordEntry entry;
  final String issueType; // 'reused', 'weak', 'stale'
  final String description;

  const PasswordHealthIssue({
    required this.entry,
    required this.issueType,
    required this.description,
  });
}

class PasswordHealthReport {
  final int totalEntries;
  final int reusedCount;
  final int weakCount;
  final int staleCount;
  final int overallHealthScore; // 0 to 100
  final List<PasswordHealthIssue> issues;

  const PasswordHealthReport({
    required this.totalEntries,
    required this.reusedCount,
    required this.weakCount,
    required this.staleCount,
    required this.overallHealthScore,
    required this.issues,
  });
}

class PasswordHealthService {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  static Future<PasswordHealthReport> analyzeHealth() async {
    if (!Hive.isBoxOpen(AppConstants.passwordBoxName)) {
      await Hive.openBox(AppConstants.passwordBoxName);
    }
    final box = Hive.box(AppConstants.passwordBoxName);

    final keyStr = await _storage.read(key: AppConstants.encryptionKeyKey);
    if (keyStr == null) {
      return const PasswordHealthReport(
        totalEntries: 0,
        reusedCount: 0,
        weakCount: 0,
        staleCount: 0,
        overallHealthScore: 100,
        issues: [],
      );
    }

    final key = base64.decode(keyStr);
    final entries = box.values
        .whereType<Map>()
        .map((m) => PasswordEntry.fromEncrypted(m.cast<String, dynamic>(), key))
        .toList();

    if (entries.isEmpty) {
      return const PasswordHealthReport(
        totalEntries: 0,
        reusedCount: 0,
        weakCount: 0,
        staleCount: 0,
        overallHealthScore: 100,
        issues: [],
      );
    }

    final issues = <PasswordHealthIssue>[];
    final passwordMap = <String, List<PasswordEntry>>{};

    for (final e in entries) {
      passwordMap.putIfAbsent(e.password, () => []).add(e);

      // Weak check
      if (e.strength < 0.5 || e.password.length < 10) {
        issues.add(PasswordHealthIssue(
          entry: e,
          issueType: 'weak',
          description: 'Weak password (${e.password.length} chars, entropy score ${(e.strength * 100).toInt()}%).',
        ));
      }

      // Stale check (> 90 days)
      if (DateTime.now().difference(e.updatedAt).inDays > 90) {
        issues.add(PasswordHealthIssue(
          entry: e,
          issueType: 'stale',
          description: 'Password last changed over 90 days ago.',
        ));
      }
    }

    // Reused check
    var reusedCount = 0;
    passwordMap.forEach((pwd, list) {
      if (list.length > 1) {
        reusedCount += list.length;
        for (final item in list) {
          issues.add(PasswordHealthIssue(
            entry: item,
            issueType: 'reused',
            description: 'Password is reused across ${list.length} different accounts.',
          ));
        }
      }
    });

    final weakCount = issues.where((i) => i.issueType == 'weak').length;
    final staleCount = issues.where((i) => i.issueType == 'stale').length;

    final penalty = (reusedCount * 15) + (weakCount * 10) + (staleCount * 5);
    final score = (100 - penalty).clamp(0, 100);

    return PasswordHealthReport(
      totalEntries: entries.length,
      reusedCount: reusedCount,
      weakCount: weakCount,
      staleCount: staleCount,
      overallHealthScore: score,
      issues: issues,
    );
  }
}
