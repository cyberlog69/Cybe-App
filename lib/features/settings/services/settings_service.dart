import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';

class SettingsService {
  static const _boxName = AppConstants.settingsBoxName;
  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  ThemeMode getThemeMode() {
    final val = _box?.get('theme_mode', defaultValue: 'system') as String;
    switch (val) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default: return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) async {
    await init();
    await _box!.put('theme_mode', mode);
  }

  int getAutoLockMinutes() {
    return (_box?.get('auto_lock_minutes', defaultValue: 5) as num).toInt();
  }

  Future<void> setAutoLockMinutes(int mins) async {
    await init();
    await _box!.put('auto_lock_minutes', mins);
  }

  bool getBiometricsEnabled() {
    return _box?.get('biometrics_enabled', defaultValue: true) as bool;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await init();
    await _box!.put('biometrics_enabled', enabled);
  }

  int getClipboardClearSeconds() {
    return (_box?.get('clipboard_clear_seconds', defaultValue: 30) as num).toInt();
  }

  Future<void> setClipboardClearSeconds(int secs) async {
    await init();
    await _box!.put('clipboard_clear_seconds', secs);
  }

  String getLanguage() {
    return _box?.get('language_code', defaultValue: 'en') as String;
  }

  Future<void> setLanguage(String code) async {
    await init();
    await _box!.put('language_code', code);
  }
}
