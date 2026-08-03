import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a version check against GitHub Releases.
class UpdateCheckResult {
  final bool updateAvailable;
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releasePageUrl;
  final DateTime publishedAt;

  const UpdateCheckResult({
    required this.updateAvailable,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.publishedAt,
  });
}

/// Service that checks the GitHub Releases API for a newer version of the app.
/// Fully FOSS-compatible — no GMS / Play Store dependency. Works on:
///   • Sideloaded APK (GitHub Release download)
///   • F-Droid (F-Droid manages its own update channel; this serves as a
///     supplementary in-app notification for users who prefer manual check)
///   • Windows & Linux (direct GitHub download link)
class UpdateCheckerService {
  static const String _owner = 'cyberlog69';
  static const String _repo = 'Cybe-App';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const String _releasesPageUrl =
      'https://github.com/$_owner/$_repo/releases/latest';

  /// Shared preference key to track when we last checked (avoid hammering API).
  static const String _lastCheckKey = 'update_last_check_epoch';

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
      final String currentVersion = info.version; // e.g. "1.0.0"

      final bool isNewer = _isVersionNewer(tagName, currentVersion);

      // Find direct APK asset URL if available
      String downloadUrl = _releasesPageUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? _releasesPageUrl;
          break;
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
      // Pad to equal length
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
