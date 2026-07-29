import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/crypto_utils.dart';

class SshKeyEntry {
  final String id;
  final String title;
  final String keyType; // 'SSH RSA', 'SSH Ed25519', 'API Token', 'Private Certificate'
  final String rawKey;
  final String notes;
  final DateTime createdAt;

  const SshKeyEntry({
    required this.id,
    required this.title,
    required this.keyType,
    required this.rawKey,
    required this.notes,
    required this.createdAt,
  });

  factory SshKeyEntry.create({
    required String title,
    required String keyType,
    required String rawKey,
    String notes = '',
    String? existingId,
  }) {
    return SshKeyEntry(
      id: existingId ?? const Uuid().v4(),
      title: title.trim(),
      keyType: keyType,
      rawKey: rawKey.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );
  }

  /// SHA-256 Key Fingerprint
  String get fingerprint {
    try {
      final bytes = utf8.encode(rawKey);
      final digest = sha256.convert(bytes);
      final hex = digest.toString().substring(0, 16).toUpperCase();
      final chunks = <String>[];
      for (var i = 0; i < hex.length; i += 2) {
        chunks.add(hex.substring(i, i + 2));
      }
      return 'SHA256:${chunks.join(":")}';
    } catch (_) {
      return 'SHA256:Unknown';
    }
  }

  Map<String, dynamic> toEncrypted(Uint8List key) {
    final encTitle = CryptoUtils.encryptText(title, key);
    final encKey = CryptoUtils.encryptText(rawKey, key);
    final encNotes = CryptoUtils.encryptText(notes, key);
    return {
      'id': id,
      'titleCipher': encTitle['ciphertext'],
      'titleIv': encTitle['iv'],
      'keyType': keyType,
      'keyCipher': encKey['ciphertext'],
      'keyIv': encKey['iv'],
      'notesCipher': encNotes['ciphertext'],
      'notesIv': encNotes['iv'],
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SshKeyEntry.fromEncrypted(Map<dynamic, dynamic> map, Uint8List key) {
    final title = CryptoUtils.decryptText(map['titleCipher'], map['titleIv'], key);
    final rawKey = CryptoUtils.decryptText(map['keyCipher'], map['keyIv'], key);
    final notes = CryptoUtils.decryptText(map['notesCipher'], map['notesIv'], key);
    return SshKeyEntry(
      id: map['id'] as String,
      title: title,
      keyType: map['keyType'] as String? ?? 'SSH Key',
      rawKey: rawKey,
      notes: notes,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
