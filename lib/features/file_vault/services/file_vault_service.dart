import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../models/vault_file_entry.dart';

// Isolate-friendly top-level encrypt/decrypt helpers
Uint8List _runEncrypt(List<dynamic> args) =>
    CryptoUtils.encryptBytes(args[0] as Uint8List, args[1] as Uint8List);

Uint8List _runDecrypt(List<dynamic> args) =>
    CryptoUtils.decryptBytes(args[0] as Uint8List, args[1] as Uint8List);

/// Service layer for the Cybe File Vault.
/// Handles AES-256-GCM encryption/decryption via Dart Isolates and
/// persists encrypted file metadata to a Hive box.
class FileVaultService {
  static const _boxName = AppConstants.vaultBoxName;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true));

  Box? _box;
  String? _vaultDir;

  /// Initialise vault directory and open Hive box (idempotent).
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDir = '${appDir.path}/cybe_vault';
    await Directory(_vaultDir!).create(recursive: true);
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  Future<Uint8List> _getVaultKey() async {
    final keyStr = await _storage.read(key: AppConstants.vaultKeyKey);
    if (keyStr == null) {
      throw Exception('Vault key not found. Complete PIN/Biometric setup first.');
    }
    return Uint8List.fromList(base64.decode(keyStr));
  }

  /// Returns all persisted vault entries sorted by newest first.
  Future<List<VaultFileEntry>> loadFiles() async {
    await init();
    return _box!.values
        .whereType<Map>()
        .map((v) => VaultFileEntry.fromMap(v))
        .where((e) => File(e.encryptedPath).existsSync())
        .toList()
      ..sort((a, b) => b.encryptedAt.compareTo(a.encryptedAt));
  }

  /// Encrypts [filePath] with AES-256-GCM in a background Isolate and
  /// stores the resulting .cybe file + metadata entry in Hive.
  Future<VaultFileEntry> importFile(String filePath, String fileName) async {
    await init();
    final key = await _getVaultKey();
    final plainBytes = await File(filePath).readAsBytes();

    // Offload heavy crypto work to Isolate to keep UI responsive
    final encrypted = await Isolate.run<Uint8List>(
        () => _runEncrypt([plainBytes, key]));

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final id = const Uuid().v4();
    final outPath = '$_vaultDir/$id.cybe';
    await File(outPath).writeAsBytes(encrypted);

    final entry = VaultFileEntry(
      id: id,
      name: fileName,
      encryptedPath: outPath,
      originalExtension: ext,
      sizeBytes: encrypted.length,
      encryptedAt: DateTime.now(),
    );
    await _box!.put(id, entry.toMap());
    return entry;
  }

  /// Decrypts [entry] in a background Isolate and writes the result to
  /// a temp file, then invokes the system share sheet.
  Future<void> shareDecrypted(VaultFileEntry entry) async {
    final key = await _getVaultKey();
    final encBytes = await File(entry.encryptedPath).readAsBytes();

    final decBytes = await Isolate.run<Uint8List>(
        () => _runDecrypt([encBytes, key]));

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/${entry.name}';
    await File(outPath).writeAsBytes(decBytes);
    await Share.shareXFiles([XFile(outPath)], text: 'Decrypted from Cybe Vault');
  }

  /// Permanently removes the encrypted file and its Hive metadata entry.
  Future<void> deleteFile(VaultFileEntry entry) async {
    await init();
    final f = File(entry.encryptedPath);
    if (await f.exists()) await f.delete();
    await _box!.delete(entry.id);
  }
}
