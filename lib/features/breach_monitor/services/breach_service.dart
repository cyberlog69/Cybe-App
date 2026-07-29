import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class BreachCheckResult {
  final String target;
  final bool isCompromised;
  final int pwnedCount;
  final List<String> breaches;
  final String message;

  const BreachCheckResult({
    required this.target,
    required this.isCompromised,
    required this.pwnedCount,
    required this.breaches,
    required this.message,
  });
}

class BreachService {
  /// Checks password against HaveIBeenPwned API using k-Anonymity SHA-1 prefixing.
  /// PLAIN TEXT PASSWORD NEVER LEAVES DEVICE.
  static Future<BreachCheckResult> checkPassword(String password) async {
    if (password.isEmpty) {
      return const BreachCheckResult(
        target: 'Password',
        isCompromised: false,
        pwnedCount: 0,
        breaches: [],
        message: 'Empty password',
      );
    }

    try {
      final bytes = utf8.encode(password);
      final sha1Hash = sha1.convert(bytes).toString().toUpperCase();
      final prefix = sha1Hash.substring(0, 5);
      final suffix = sha1Hash.substring(5);

      final url = Uri.parse('https://api.pwnedpasswords.com/range/$prefix');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        for (final line in lines) {
          final parts = line.trim().split(':');
          if (parts.length == 2 && parts[0].toUpperCase() == suffix) {
            final count = int.tryParse(parts[1]) ?? 1;
            return BreachCheckResult(
              target: 'Password',
              isCompromised: true,
              pwnedCount: count,
              breaches: ['Pwned Passwords Database'],
              message: 'Found in $count data breaches! Change this password immediately.',
            );
          }
        }
        return const BreachCheckResult(
          target: 'Password',
          isCompromised: false,
          pwnedCount: 0,
          breaches: [],
          message: 'Safe! No occurrences found in known data breaches.',
        );
      }
      return const BreachCheckResult(
        target: 'Password',
        isCompromised: false,
        pwnedCount: 0,
        breaches: [],
        message: 'Breach service unavailable',
      );
    } catch (e) {
      return BreachCheckResult(
        target: 'Password',
        isCompromised: false,
        pwnedCount: 0,
        breaches: [],
        message: 'Network check error: $e',
      );
    }
  }

  /// Performs simulated domain/email leak lookup
  static Future<BreachCheckResult> checkEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      return BreachCheckResult(
        target: email,
        isCompromised: false,
        pwnedCount: 0,
        breaches: [],
        message: 'Invalid email address',
      );
    }

    await Future.delayed(const Duration(milliseconds: 600));
    final domain = email.split('@').last.toLowerCase();
    
    final knownBreachedDomains = {
      'adobe.com': ['Adobe 2013 Breach (153M records)'],
      'linkedin.com': ['LinkedIn 2016 Leak (164M records)'],
      'canva.com': ['Canva 2019 Leak (137M records)'],
      'dropbox.com': ['Dropbox 2012 Leak (68M records)'],
    };

    if (knownBreachedDomains.containsKey(domain)) {
      final leaks = knownBreachedDomains[domain]!;
      return BreachCheckResult(
        target: email,
        isCompromised: true,
        pwnedCount: leaks.length,
        breaches: leaks,
        message: 'Domain $domain was compromised in major historical leaks.',
      );
    }

    return BreachCheckResult(
      target: email,
      isCompromised: false,
      pwnedCount: 0,
      breaches: [],
      message: 'No active breaches reported for $email domain.',
    );
  }
}
