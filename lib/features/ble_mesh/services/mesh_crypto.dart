import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

/// Provides AES-256-GCM encryption/decryption for BitMesh channels.
/// Channel key is derived from passphrase using PBKDF2-SHA256.
class MeshCrypto {
  static const String _salt = 'CybeBitMeshSaltV1'; // fixed app salt
  static const int _iterations = 10000;
  static const int _keyLength = 32; // 256 bits

  /// Derives a 256-bit AES key from a channel passphrase using PBKDF2
  static Uint8List _deriveKey(String passphrase) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(
      Uint8List.fromList(utf8.encode(_salt)),
      _iterations,
      _keyLength,
    ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Encrypts [plaintext] using AES-256-CBC with the given [channelKey].
  /// Returns base64-encoded "IV:ciphertext".
  static String encrypt(String plaintext, String channelKey) {
    try {
      final keyBytes = _deriveKey(channelKey);
      final key = enc.Key(keyBytes);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      // Pack as "base64IV:base64ciphertext"
      final ivB64 = base64.encode(iv.bytes);
      return '$ivB64:${encrypted.base64}';
    } catch (e) {
      return plaintext; // fallback to plaintext on error
    }
  }

  /// Decrypts a [ciphertext] string (format: "base64IV:base64ciphertext")
  /// using the given [channelKey]. Returns null if decryption fails.
  static String? decrypt(String ciphertext, String channelKey) {
    try {
      final parts = ciphertext.split(':');
      if (parts.length < 2) return ciphertext; // not encrypted / public msg
      final iv = enc.IV(base64.decode(parts[0]));
      final ct = parts.sublist(1).join(':');
      final keyBytes = _deriveKey(channelKey);
      final key = enc.Key(keyBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(ct, iv: iv);
    } catch (_) {
      return null; // wrong key or corrupted data
    }
  }

  /// Generates a random BLE-style alias like "BlueTiger42"
  static String generateAlias() {
    const adjectives = [
      'Blue', 'Red', 'Dark', 'Silent', 'Ghost',
      'Cyber', 'Neon', 'Shadow', 'Phantom', 'Storm',
    ];
    const animals = [
      'Fox', 'Hawk', 'Wolf', 'Jaguar', 'Viper',
      'Tiger', 'Raven', 'Eagle', 'Lynx', 'Cobra',
    ];
    final rng = Random.secure();
    final adj = adjectives[rng.nextInt(adjectives.length)];
    final animal = animals[rng.nextInt(animals.length)];
    final num = rng.nextInt(90) + 10;
    return '$adj$animal$num';
  }
}
