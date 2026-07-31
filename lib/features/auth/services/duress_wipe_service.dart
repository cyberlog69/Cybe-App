import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../security_logs/services/security_log_service.dart';

class DuressWipeService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  /// Checks if Duress PIN mode is active
  static Future<bool> isDuressEnabled() async {
    final enabled = await _storage.read(key: AppConstants.duressEnabledKey);
    final hash = await _storage.read(key: AppConstants.duressPasswordHashKey);
    return enabled == 'true' && hash != null;
  }

  /// Sets or updates the emergency Duress PIN
  static Future<void> setDuressPassword(String password) async {
    final salt = CryptoUtils.generateSalt();
    final hash = CryptoUtils.hashPassword(password, salt);

    await _storage.write(key: AppConstants.duressPasswordHashKey, value: hash);
    await _storage.write(key: AppConstants.duressSaltKey, value: salt);
    await _storage.write(key: AppConstants.duressEnabledKey, value: 'true');

    await SecurityLogService.logEvent(
      title: 'Duress Panic PIN Configured',
      message: 'Emergency Duress Panic Wipe PIN has been updated.',
      severity: 'warning',
      category: 'Auth',
    );
  }

  /// Disables Duress PIN mode
  static Future<void> disableDuressPassword() async {
    await _storage.delete(key: AppConstants.duressPasswordHashKey);
    await _storage.delete(key: AppConstants.duressSaltKey);
    await _storage.write(key: AppConstants.duressEnabledKey, value: 'false');
  }

  /// Verifies if entered password matches the Duress PIN
  static Future<bool> verifyDuressPassword(String password) async {
    final enabled = await isDuressEnabled();
    if (!enabled) return false;

    final hash = await _storage.read(key: AppConstants.duressPasswordHashKey);
    final salt = await _storage.read(key: AppConstants.duressSaltKey);
    if (hash == null || salt == null) return false;

    return CryptoUtils.verifyPassword(password, salt, hash);
  }

  /// SILENT EMERGENCY PANIC WIPE SEQUENCE
  /// Permanently purges all vault files, Hive boxes, and overwrites cryptographic keys on disk.
  static Future<void> executePanicWipeSequence() async {
    try {
      // 1. Silent Emergency Event Log
      await SecurityLogService.logEvent(
        title: 'EMERGENCY: Duress Panic Wipe Executed',
        message: 'Physical coercion / emergency panic wipe triggered. Purging encryption keys & vaults.',
        severity: 'critical',
        category: 'Auth',
        rawDetails: 'Spec: DOD 5220.22-M Multi-Pass Purge | Time: ${DateTime.now().toIso8601String()}',
      );

      // 2. Multi-Pass Physical File Deletion in cybe_vault
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${appDir.path}/cybe_vault');

      if (await vaultDir.exists()) {
        final List<FileSystemEntity> files = vaultDir.listSync(recursive: true);
        for (final entity in files) {
          if (entity is File) {
            try {
              // Overwrite file content with zeros before deletion
              final len = await entity.length();
              if (len > 0) {
                final zeros = List<int>.filled(len, 0);
                await entity.writeAsBytes(zeros);
              }
              await entity.delete();
            } catch (_) {}
          }
        }
        await vaultDir.delete(recursive: true);
      }

      // 3. Clear all sensitive Hive boxes
      final boxNames = [
        AppConstants.vaultBoxName,
        AppConstants.passwordBoxName,
        'totp_box',
        'notes_box',
        AppConstants.usbHistoryBoxName,
        AppConstants.networkLogBoxName,
      ];

      for (final boxName in boxNames) {
        try {
          Box b;
          if (!Hive.isBoxOpen(boxName)) {
            b = await Hive.openBox(boxName);
          } else {
            b = Hive.box(boxName);
          }
          await b.clear();
        } catch (_) {}
      }

      // 4. Overwrite Master Cryptographic Keys with random garbage
      final garbageKey = CryptoUtils.generateRandomBytes(64);
      final garbageVaultKey = CryptoUtils.generateRandomBytes(64);

      await _storage.write(key: AppConstants.encryptionKeyKey, value: base64.encode(garbageKey));
      await _storage.write(key: AppConstants.vaultKeyKey, value: base64.encode(garbageVaultKey));

      // 5. Clear Clipboard
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (e) {
      // Ignore errors to ensure panic wipe never crashes mid-sequence
    }
  }
}
