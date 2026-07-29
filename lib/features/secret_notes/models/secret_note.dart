import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../../core/utils/crypto_utils.dart';

class SecretNote {
  final String id;
  final String title;
  final String content;
  final String category;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecretNote({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SecretNote.create({
    required String title,
    required String content,
    String category = 'Personal',
    bool isPinned = false,
    String? existingId,
  }) {
    final now = DateTime.now();
    return SecretNote(
      id: existingId ?? const Uuid().v4(),
      title: title,
      content: content,
      category: category,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toEncrypted(Uint8List key) {
    final encTitle = CryptoUtils.encryptText(title, key);
    final encContent = CryptoUtils.encryptText(content, key);
    return {
      'id': id,
      'titleCipher': encTitle['ciphertext'],
      'titleIv': encTitle['iv'],
      'contentCipher': encContent['ciphertext'],
      'contentIv': encContent['iv'],
      'category': category,
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SecretNote.fromEncrypted(Map<dynamic, dynamic> map, Uint8List key) {
    final title = CryptoUtils.decryptText(map['titleCipher'], map['titleIv'], key);
    final content = CryptoUtils.decryptText(map['contentCipher'], map['contentIv'], key);
    return SecretNote(
      id: map['id'] as String,
      title: title,
      content: content,
      category: map['category'] as String? ?? 'Personal',
      isPinned: map['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
