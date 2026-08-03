import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The platform the app is currently running on, used to pick the right asset.
enum AppPlatform { android, windows, linux, macos, ios, web }

/// Result of a version check against GitHub Releases.
class UpdateCheckResult {
  final bool updateAvailable;
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releasePageUrl;
  final DateTime publishedAt;
  final AppPlatform platform;

  const UpdateCheckResult({
    required this.updateAvailable,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.publishedAt,
    required this.platform,
  });

  /// Human-readable platform name for UI display.
  String get platformLabel {
    switch (platform) {
      case AppPlatform.android:  return 'Android APK';
      case AppPlatform.windows:  return 'Windows (.zip)';
      case AppPlatform.linux:    return 'Linux (.tar.gz)';
      case AppPlatform.macos:    return 'macOS (.dmg)';
      case AppPlatform.ios:      return 'iOS (App Store)';
      case AppPlatform.web:      return 'Web';
    }
  }

  /// Icon for the platform download button.
  String get platformEmoji {
    switch (platform) {
      case AppPlatform.android:  return '📱';
      case AppPlatform.windows:  return '🪟';
      case AppPlatform.linux:    return '🐧';
      case AppPlatform.macos:    return '🍎';
      case AppPlatform.ios:      return '📱';
      case AppPlatform.web:      return '🌐';
    }
  }
}

/// Service that checks the GitHub Releases API for a newer version of the app.
/// Fully FOSS-compatible — no GMS / Play Store dependency.
///
/// Supported platforms: Android, Windows, Linux, macOS, iOS, Web
class UpdateCheckerService {
  static const String _owner = 'cyberlog69';
  static const String _repo = 'Cybe-App';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const String _releasesPageUrl =
      'https://github.com/$_owner/$_repo/releases/latest';

  /// Shared preference key to track when we last checked (avoid hammering API).
  static const String _lastCheckKey = 'update_last_check_epoch';

  /// Detect the current runtime platform.
  static AppPlatform get currentPlatform {
    if (kIsWeb) return AppPlatform.web;
    if (Platform.isAndroid) return AppPlatform.android;
    if (Platform.isWindows) return AppPlatform.windows;
    if (Platform.isLinux)   return AppPlatform.linux;
    if (Platform.isMacOS)   return AppPlatform.macos;
    if (Platform.isIOS)     return AppPlatform.ios;
    return AppPlatform.web;
  }

  /// File extension suffixes we look for per platform in the GitHub Release assets.
  static List<String> _assetSuffixesForPlatform(AppPlatform platform) {
    switch (platform) {
      case AppPlatform.android: return ['.apk'];
      case AppPlatform.windows: return ['-windows.zip', 'windows.zip', '.zip', '.exe'];
      case AppPlatform.linux:   return ['-linux.tar.gz', 'linux.tar.gz', '.tar.gz', '-linux.zip', 'linux.zip'];
      case AppPlatform.macos:   return ['-macos.dmg', 'macos.dmg', '.dmg', '-mac.dmg'];
      case AppPlatform.ios:     return [];  // iOS updates via App Store
      case AppPlatform.web:     return [];
    }
  }

  /// Check if a newer version is available on GitHub.
  /// [forceCheck] skips the 24-hour cooldown used for background auto-checks.
  static Future<UpdateCheckResult?> checkForUpdate({bool forceCheck = false}) async {
    // Throttle background checks to once per 24 hours
    if (!forceCheck) {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < const Duration(hours: 24).inMilliseconds) {
        return null; // Too soon — skip silently
      }
      await prefs.setInt(_lastCheckKey, now);
    }

    try {
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> json = jsonDecode(response.body);

      // Parse latest version from tag: "v1.2.3" → "1.2.3"
      final String tagName = (json['tag_name'] as String? ?? '').replaceAll('v', '').trim();
      if (tagName.isEmpty) return null;

      // Get current app version from pubspec via package_info_plus
      final info = await PackageInfo.fromPlatform();
      final String currentVersion = info.version;

      final bool isNewer = _isVersionNewer(tagName, currentVersion);

      // Detect runtime platform and find the matching asset
      final platform = currentPlatform;
      final suffixes = _assetSuffixesForPlatform(platform);
      String downloadUrl = _releasesPageUrl; // fallback to releases page

      if (suffixes.isNotEmpty) {
        final assets = json['assets'] as List<dynamic>? ?? [];
        // Try each preferred suffix in priority order
        outer:
        for (final suffix in suffixes) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith(suffix)) {
              downloadUrl = asset['browser_download_url'] as String? ?? _releasesPageUrl;
              break outer;
            }
          }
        }
      }

      final String body = json['body'] as String? ?? 'No release notes available.';
      final String publishedStr = json['published_at'] as String? ?? DateTime.now().toIso8601String();

      return UpdateCheckResult(
        updateAvailable: isNewer,
        latestVersion: tagName,
        currentVersion: currentVersion,
        releaseNotes: _trimReleaseNotes(body),
        downloadUrl: downloadUrl,
        releasePageUrl: _releasesPageUrl,
        publishedAt: DateTime.tryParse(publishedStr) ?? DateTime.now(),
        platform: platform,
      );
    } catch (_) {
      return null; // Network error — fail silently
    }
  }

  /// Compare two semver strings: "1.2.3" vs "1.0.0".
  /// Returns true if [latest] is strictly newer than [current].
  static bool _isVersionNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      while (l.length < 3) { l.add(0); }
      while (c.length < 3) { c.add(0); }
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false; // Equal versions
    } catch (_) {
      return false;
    }
  }

  /// Trim very long release notes to a readable length.
  static String _trimReleaseNotes(String notes) {
    const maxLength = 800;
    if (notes.length <= maxLength) return notes;
    return '${notes.substring(0, maxLength)}…\n\n[See full release notes on GitHub]';
  }
}
