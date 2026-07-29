import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/crypto_utils.dart';

class BackupService {

  /// Export all Hive vaults (Passwords, Secret Notes, TOTP) into an AES-256 encrypted `.cybe` file.
  static Future<String> exportBackup(String masterPassword) async {
    final salt = CryptoUtils.generateSalt();
    final key = CryptoUtils.deriveKey(masterPassword, salt);

    final payload = <String, dynamic>{
      'version': AppConstants.appVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'passwords': [],
      'notes': [],
      'totp': [],
    };

    if (Hive.isBoxOpen(AppConstants.passwordBoxName)) {
      payload['passwords'] = Hive.box(AppConstants.passwordBoxName).values.toList();
    }
    if (Hive.isBoxOpen('secret_notes_box')) {
      payload['notes'] = Hive.box('secret_notes_box').values.toList();
    }
    if (Hive.isBoxOpen('totp_box')) {
      payload['totp'] = Hive.box('totp_box').values.toList();
    }

    final jsonStr = jsonEncode(payload);
    final encrypted = CryptoUtils.encryptText(jsonStr, key);

    final container = jsonEncode({
      'salt': salt,
      'ciphertext': encrypted['ciphertext'],
      'iv': encrypted['iv'],
    });

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/cybe_backup_${DateTime.now().millisecondsSinceEpoch}.cybe';
    await File(filePath).writeAsString(container);
    return filePath;
  }

  /// Import and decrypt a `.cybe` backup container.
  static Future<bool> restoreBackup(String filePath, String masterPassword) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Backup file not found');

    final containerStr = await file.readAsString();
    final container = jsonDecode(containerStr) as Map<String, dynamic>;

    final salt = container['salt'] as String;
    final ciphertext = container['ciphertext'] as String;
    final iv = container['iv'] as String;

    final key = CryptoUtils.deriveKey(masterPassword, salt);
    final decryptedJson = CryptoUtils.decryptText(ciphertext, iv, key);
    final payload = jsonDecode(decryptedJson) as Map<String, dynamic>;

    final passwords = payload['passwords'] as List?;
    if (passwords != null && Hive.isBoxOpen(AppConstants.passwordBoxName)) {
      final box = Hive.box(AppConstants.passwordBoxName);
      for (final raw in passwords) {
        if (raw is Map) {
          await box.put(raw['id'], raw);
        }
      }
    }

    final notes = payload['notes'] as List?;
    if (notes != null && Hive.isBoxOpen('secret_notes_box')) {
      final box = Hive.box('secret_notes_box');
      for (final raw in notes) {
        if (raw is Map) {
          await box.put(raw['id'], raw);
        }
      }
    }

    final totp = payload['totp'] as List?;
    if (totp != null && Hive.isBoxOpen('totp_box')) {
      final box = Hive.box('totp_box');
      for (final raw in totp) {
        if (raw is Map) {
          await box.put(raw['id'], raw);
        }
      }
    }

    return true;
  }
}
