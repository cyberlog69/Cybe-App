import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/secret_note.dart';

class SecretNotesService {
  static const _boxName = 'secret_notes_box';
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
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

  Future<List<SecretNote>> loadNotes() async {
    await init();
    final key = await _getKey();
    return _box!.values
        .whereType<Map>()
        .map((m) => SecretNote.fromEncrypted(m, key))
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  Future<void> saveNote(SecretNote note) async {
    await init();
    final key = await _getKey();
    await _box!.put(note.id, note.toEncrypted(key));
  }

  Future<void> deleteNote(String id) async {
    await init();
    await _box!.delete(id);
  }
}
