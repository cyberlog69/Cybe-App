import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

class CryptoUtils {
  static final _random = Random.secure();

  /// Generate cryptographically secure random bytes
  static Uint8List generateRandomBytes(int length) {
    return Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
  }

  /// Generate a random Base64Url-encoded salt
  static String generateSalt() {
    return base64Url.encode(generateRandomBytes(32));
  }

  /// Derive a 256-bit key from a master password using PBKDF2-SHA256
  static Uint8List deriveKey(String password, String salt, {int iterations = 100000}) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Url.decode(salt);
    final params = Pbkdf2Parameters(Uint8List.fromList(saltBytes), iterations, 32);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(params);
    return pbkdf2.process(Uint8List.fromList(passwordBytes));
  }

  /// Encrypt plaintext string with AES-256-CBC, returns {ciphertext, iv}
  static Map<String, String> encryptText(String plaintext, Uint8List key) {
    final ivBytes = generateRandomBytes(16);
    final encKey = enc.Key(key);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return {
      'ciphertext': encrypted.base64,
      'iv': base64.encode(ivBytes),
    };
  }

  /// Decrypt ciphertext string with AES-256-CBC
  static String decryptText(String ciphertext, String ivBase64, Uint8List key) {
    final encKey = enc.Key(key);
    final iv = enc.IV(base64.decode(ivBase64));
    final encrypter = enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(ciphertext, iv: iv);
  }

  /// Encrypt file bytes with AES-256-GCM (authenticated encryption)
  /// Returns: [12-byte IV | ciphertext+auth_tag]
  static Uint8List encryptBytes(Uint8List plainBytes, Uint8List key) {
    final ivBytes = generateRandomBytes(12);
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, ivBytes, Uint8List(0));
    cipher.init(true, params);
    final encrypted = cipher.process(plainBytes);
    return Uint8List.fromList([...ivBytes, ...encrypted]);
  }

  /// Decrypt bytes encrypted with encryptBytes (AES-256-GCM)
  static Uint8List decryptBytes(Uint8List encryptedWithIv, Uint8List key) {
    final ivBytes = encryptedWithIv.sublist(0, 12);
    final cipherBytes = encryptedWithIv.sublist(12);
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, ivBytes, Uint8List(0));
    cipher.init(false, params);
    return cipher.process(cipherBytes);
  }

  /// Hash master password for storage verification (PBKDF2 at reduced cost)
  static String hashPassword(String password, String salt) {
    final keyBytes = deriveKey(password, salt, iterations: 10000);
    return base64.encode(keyBytes);
  }

  /// Verify entered password against stored hash
  static bool verifyPassword(String password, String salt, String storedHash) {
    return hashPassword(password, salt) == storedHash;
  }

  /// Generate a strong random password
  static String generatePassword({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const nums = '0123456789';
    const syms = r'!@#$%^&*()-_=+[]{}|;:,.<>?';

    String chars = '';
    if (uppercase) chars += upper;
    if (lowercase) chars += lower;
    if (numbers) chars += nums;
    if (symbols) chars += syms;
    if (chars.isEmpty) chars = lower + nums;

    // Ensure at least one of each selected type
    final List<String> result = [];
    if (uppercase && chars.contains(upper[0])) result.add(upper[_random.nextInt(upper.length)]);
    if (lowercase && chars.contains(lower[0])) result.add(lower[_random.nextInt(lower.length)]);
    if (numbers && chars.contains(nums[0])) result.add(nums[_random.nextInt(nums.length)]);
    if (symbols && chars.contains(syms[0])) result.add(syms[_random.nextInt(syms.length)]);

    while (result.length < length) {
      result.add(chars[_random.nextInt(chars.length)]);
    }
    result.shuffle(_random);
    return result.take(length).join();
  }

  /// Calculate password entropy-based strength (0.0–1.0)
  static double passwordStrength(String password) {
    if (password.isEmpty) return 0;
    double score = 0;
    if (password.length >= 8) score += 0.1;
    if (password.length >= 12) score += 0.15;
    if (password.length >= 16) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.15;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 0.10;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.15;
    if (RegExp(r'[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/|\\`~]').hasMatch(password)) score += 0.20;
    return score.clamp(0.0, 1.0);
  }

  static String passwordStrengthLabel(double strength) {
    if (strength < 0.2) return 'Very Weak';
    if (strength < 0.4) return 'Weak';
    if (strength < 0.6) return 'Fair';
    if (strength < 0.8) return 'Strong';
    return 'Very Strong';
  }
}
