import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'mesh_relay.dart';

class GitHubUpdateInfo {
  final String repo;
  final String latestTag;
  final String releaseName;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
  final DateTime publishedAt;
  final bool hasNewUpdate;

  GitHubUpdateInfo({
    required this.repo,
    required this.latestTag,
    required this.releaseName,
    required this.releaseNotes,
    this.apkDownloadUrl,
    this.apkSizeBytes,
    required this.publishedAt,
    required this.hasNewUpdate,
  });
}

class GitHubSyncEngine {
  final String repository; // e.g. "cyberlog69/Cybe-App"
  final String currentVersion;
  final String? gitHubToken;
  final BitMeshRelayServer? relayServer;
  final void Function(String message)? onLog;
  final void Function(GitHubUpdateInfo update)? onUpdateFound;

  Timer? _pollTimer;
  String _lastCheckedTag = '';

  GitHubSyncEngine({
    this.repository = 'cyberlog69/Cybe-App',
    this.currentVersion = 'v1.0.0',
    this.gitHubToken,
    this.relayServer,
    this.onLog,
    this.onUpdateFound,
  });

  void _log(String text) {
    if (onLog != null) {
      onLog!('[GitHub Sync] $text');
    } else {
      stdout.writeln('[GitHub Sync] $text');
    }
  }

  void startPolling({Duration interval = const Duration(minutes: 15)}) {
    _log('Starting GitHub release monitor for "$repository" (Checking every ${interval.inMinutes}m)...');
    checkUpdates();
    _pollTimer = Timer.periodic(interval, (_) => checkUpdates());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<GitHubUpdateInfo?> checkUpdates() async {
    final url = Uri.parse('https://api.github.com/repos/$repository/releases/latest');
    final headers = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'Cybe-Relay-Daemon/1.0',
      if (gitHubToken != null && gitHubToken!.isNotEmpty)
        'Authorization': 'token $gitHubToken',
    };

    try {
      _log('Checking GitHub for latest release: $url');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = json['tag_name'] as String? ?? '';
        final releaseName = json['name'] as String? ?? tagName;
        final body = json['body'] as String? ?? '';
        final publishedAtStr = json['published_at'] as String? ?? DateTime.now().toIso8601String();
        final publishedAt = DateTime.tryParse(publishedAtStr) ?? DateTime.now();

        String? apkUrl;
        int? apkSize;

        final assets = json['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final assetMap = asset as Map<String, dynamic>;
          final name = assetMap['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = assetMap['browser_download_url'] as String?;
            apkSize = assetMap['size'] as int?;
            break;
          }
        }

        final isNewer = tagName.isNotEmpty && tagName != currentVersion && tagName != _lastCheckedTag;

        final info = GitHubUpdateInfo(
          repo: repository,
          latestTag: tagName,
          releaseName: releaseName,
          releaseNotes: body,
          apkDownloadUrl: apkUrl,
          apkSizeBytes: apkSize,
          publishedAt: publishedAt,
          hasNewUpdate: isNewer,
        );

        if (isNewer) {
          _lastCheckedTag = tagName;
          _log('🎉 New release detected: $tagName ("$releaseName")');
          if (apkUrl != null) {
            _log('APK Download: $apkUrl (${((apkSize ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB)');
          }

          onUpdateFound?.call(info);

          // Broadcast announcement over BitMesh to connected Android nodes
          relayServer?.broadcastMessage(
            channel: 'cybe-public',
            plaintextOrData: jsonEncode({
              'event': 'NEW_RELEASE_AVAILABLE',
              'tag': tagName,
              'title': releaseName,
              'apkUrl': apkUrl,
              'notes': body.length > 200 ? '${body.substring(0, 197)}...' : body,
              'ts': DateTime.now().millisecondsSinceEpoch,
            }),
            customFrom: 'Relay-GitHub-Bot',
          );
        } else {
          _log('App is up to date with latest release ($tagName).');
        }

        return info;
      } else if (response.statusCode == 404) {
        _log('No releases published yet on $repository.');
      } else {
        _log('GitHub API response ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      _log('Failed to query GitHub API: $e');
    }
    return null;
  }

  Future<File?> downloadApk(String apkUrl, String targetDirectory) async {
    try {
      final dir = Directory(targetDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName = Uri.parse(apkUrl).pathSegments.last;
      final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');

      _log('Downloading update: $fileName ...');
      final res = await http.get(Uri.parse(apkUrl));

      if (res.statusCode == 200) {
        await targetFile.writeAsBytes(res.bodyBytes);
        _log('✅ Download complete: ${targetFile.path} (${(res.bodyBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB)');
        return targetFile;
      }
    } catch (e) {
      _log('Download error: $e');
    }
    return null;
  }
}
