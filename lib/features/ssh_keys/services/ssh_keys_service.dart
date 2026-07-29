import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/ssh_key_entry.dart';

class SshKeysService {
  static const _boxName = 'ssh_keys_box';
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions());
  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  Future<Uint8List> _getKey() async {
    final keyStr = await _storage.read(key: AppConstants.encryptionKeyKey);
    if (keyStr == null) throw Exception('Master key not initialized');
    return Uint8List.fromList(base64.decode(keyStr));
  }

  Future<List<SshKeyEntry>> loadKeys() async {
    await init();
    final key = await _getKey();
    return _box!.values
        .whereType<Map>()
        .map((m) => SshKeyEntry.fromEncrypted(m, key))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveKey(SshKeyEntry entry) async {
    await init();
    final key = await _getKey();
    await _box!.put(entry.id, entry.toEncrypted(key));
  }

  Future<void> deleteKey(String id) async {
    await init();
    await _box!.delete(id);
  }
}
