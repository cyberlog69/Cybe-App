import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class TotpItem {
  final String id;
  final String issuer;
  final String accountName;
  final String secret;
  final int period; // seconds (default 30)
  final int digits; // default 6
  final DateTime createdAt;

  const TotpItem({
    required this.id,
    required this.issuer,
    required this.accountName,
    required this.secret,
    this.period = 30,
    this.digits = 6,
    required this.createdAt,
  });

  factory TotpItem.create({
    required String issuer,
    required String accountName,
    required String secret,
    int period = 30,
    int digits = 6,
  }) {
    return TotpItem(
      id: const Uuid().v4(),
      issuer: issuer.trim(),
      accountName: accountName.trim(),
      secret: secret.replaceAll(' ', '').toUpperCase(),
      period: period,
      digits: digits,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'issuer': issuer,
    'accountName': accountName,
    'secret': secret,
    'period': period,
    'digits': digits,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TotpItem.fromMap(Map<dynamic, dynamic> map) => TotpItem(
    id: map['id'] as String,
    issuer: map['issuer'] as String? ?? 'Account',
    accountName: map['accountName'] as String? ?? '',
    secret: map['secret'] as String,
    period: (map['period'] as num?)?.toInt() ?? 30,
    digits: (map['digits'] as num?)?.toInt() ?? 6,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  /// Generates the current 6-digit TOTP code according to RFC 6238 / RFC 4226
  String get currentCode {
    return generateCodeForTime(DateTime.now());
  }

  /// Progress fraction (0.0 to 1.0) of current time step remaining
  double get timeRemainingFraction {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rem = nowSeconds % period;
    return (period - rem) / period;
  }

  int get secondsRemaining {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return period - (nowSeconds % period);
  }

  String generateCodeForTime(DateTime time) {
    try {
      final timeSeconds = time.millisecondsSinceEpoch ~/ 1000;
      final counter = timeSeconds ~/ period;
      final secretBytes = _base32Decode(secret);
      if (secretBytes.isEmpty) return '000000';

      // 8-byte big endian counter
      final counterBytes = Uint8List(8);
      var tempCounter = counter;
      for (var i = 7; i >= 0; i--) {
        counterBytes[i] = tempCounter & 0xff;
        tempCounter >>= 8;
      }

      final hmac = Hmac(sha1, secretBytes);
      final digest = hmac.convert(counterBytes).bytes;

      final offset = digest[digest.length - 1] & 0x0f;
      final binary = ((digest[offset] & 0x7f) << 24) |
          ((digest[offset + 1] & 0xff) << 16) |
          ((digest[offset + 2] & 0xff) << 8) |
          (digest[offset + 3] & 0xff);

      final otp = binary % _pow10(digits);
      return otp.toString().padLeft(digits, '0');
    } catch (_) {
      return '------';
    }
  }

  static int _pow10(int exp) {
    var res = 1;
    for (var i = 0; i < exp; i++) {
      res *= 10;
    }
    return res;
  }

  static Uint8List _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleanInput = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    if (cleanInput.isEmpty) return Uint8List(0);

    var buffer = 0;
    var bitsLeft = 0;
    final result = <int>[];

    for (var i = 0; i < cleanInput.length; i++) {
      final char = cleanInput[i];
      final val = alphabet.indexOf(char);
      if (val < 0) continue;

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        result.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }
    return Uint8List.fromList(result);
  }
}
