import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../../core/utils/crypto_utils.dart';

class PasswordEntry {
  final String id;
  final String site;
  final String username;
  final String password;
  final String category;
  final String url;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PasswordEntry({
    required this.id,
    required this.site,
    required this.username,
    required this.password,
    required this.category,
    required this.url,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PasswordEntry.create({
    required String site,
    required String username,
    required String password,
    String category = 'Other',
    String url = '',
    String notes = '',
    String? existingId,
  }) {
    final now = DateTime.now();
    return PasswordEntry(
      id: existingId ?? const Uuid().v4(),
      site: site,
      username: username,
      password: password,
      category: category,
      url: url,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toEncrypted(List<int> keyBytes) {
    final key = Uint8List.fromList(keyBytes);
    final encPwd = CryptoUtils.encryptText(password, key);
    final encNotes = notes.isNotEmpty ? CryptoUtils.encryptText(notes, key) : {'ciphertext': '', 'iv': ''};
    return {
      'id': id,
      'site': site,
      'username': username,
      'passwordCipher': encPwd['ciphertext'],
      'passwordIv': encPwd['iv'],
      'category': category,
      'url': url,
      'notesCipher': encNotes['ciphertext'],
      'notesIv': encNotes['iv'],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PasswordEntry.fromEncrypted(Map<String, dynamic> map, List<int> keyBytes) {
    final key = Uint8List.fromList(keyBytes);
    final password = CryptoUtils.decryptText(map['passwordCipher'], map['passwordIv'], key);
    final notes = (map['notesCipher'] as String).isNotEmpty
        ? CryptoUtils.decryptText(map['notesCipher'], map['notesIv'], key)
        : '';
    return PasswordEntry(
      id: map['id'],
      site: map['site'],
      username: map['username'],
      password: password,
      category: map['category'] ?? 'Other',
      url: map['url'] ?? '',
      notes: notes,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  double get strength => CryptoUtils.passwordStrength(password);
  String get strengthLabel => CryptoUtils.passwordStrengthLabel(strength);
}
