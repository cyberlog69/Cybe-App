import 'package:hive_flutter/hive_flutter.dart';
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
  }

  Future<void> deleteItem(String id) async {
    await init();
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
