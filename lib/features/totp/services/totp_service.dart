import 'package:hive_flutter/hive_flutter.dart';
import '../../security_logs/services/security_log_service.dart';
import '../models/totp_item.dart';

class TotpService {
  static const _boxName = 'totp_box';
  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
    await _purgeLegacyDemoEntries();
  }

  /// Purges legacy hardcoded demo entries (e.g. cyberlog69 / demo keys)
  Future<void> _purgeLegacyDemoEntries() async {
    if (_box == null) return;
    final keysToRemove = <dynamic>[];
    for (final key in _box!.keys) {
      final val = _box!.get(key);
      if (val is Map) {
        final acc = (val['accountName'] ?? '').toString();
        final iss = (val['issuer'] ?? '').toString();
        final sec = (val['secret'] ?? '').toString();
        if (acc == 'cyberlog69' ||
            acc == 'user@gmail.com' ||
            iss == 'Google' ||
            iss == 'GitHub' ||
            sec == 'JBSWY3DPEHPK3PXP' ||
            sec == 'HXDMVJECJJWSRB3L') {
          keysToRemove.add(key);
        }
      }
    }
    for (final k in keysToRemove) {
      await _box!.delete(k);
    }
  }

  Future<List<TotpItem>> loadItems() async {
    await init();
    return _box!.values
        .whereType<Map>()
        .map((v) => TotpItem.fromMap(v))
        .toList()
      ..sort((a, b) => a.issuer.toLowerCase().compareTo(b.issuer.toLowerCase()));
  }

  Future<void> addItem(TotpItem item) async {
    await init();
    await _box!.put(item.id, item.toMap());

    await SecurityLogService.logEvent(
      title: '2FA Token Added',
      message: 'Created 2FA authenticator entry for "${item.issuer}" (${item.accountName}).',
      severity: 'safe',
      category: 'Auth',
    );
  }

  Future<void> deleteItem(String id) async {
    await init();
    final rawMap = _box!.get(id);
    if (rawMap != null && rawMap is Map) {
      final item = TotpItem.fromMap(rawMap);
      await SecurityLogService.logEvent(
        title: '2FA Token Removed',
        message: 'Deleted 2FA entry for "${item.issuer}" (${item.accountName}).',
        severity: 'info',
        category: 'Auth',
      );
    }
    await _box!.delete(id);
  }

  /// Parse otpauth://totp/Issuer:account?secret=XYZ&issuer=Issuer
  static TotpItem? parseOtpAuthUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.scheme != 'otpauth' || uri.host != 'totp') return null;

      final secret = uri.queryParameters['secret'];
      if (secret == null || secret.isEmpty) return null;

      final label = Uri.decodeComponent(uri.path.substring(1));
      String issuer = uri.queryParameters['issuer'] ?? '';
      String account = label;

      if (label.contains(':')) {
        final parts = label.split(':');
        if (issuer.isEmpty) issuer = parts[0];
        account = parts.sublist(1).join(':').trim();
      }

      final digits = int.tryParse(uri.queryParameters['digits'] ?? '6') ?? 6;
      final period = int.tryParse(uri.queryParameters['period'] ?? '30') ?? 30;

      return TotpItem.create(
        issuer: issuer.isEmpty ? 'Service' : issuer,
        accountName: account,
        secret: secret,
        digits: digits,
        period: period,
      );
    } catch (_) {
      return null;
    }
  }
}
