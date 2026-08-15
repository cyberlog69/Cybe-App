import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class FileAnalysisEntry {
  final String relativePath;
  final int sizeBytes;
  final String sha256Hash;
  final DateTime lastModified;
  final bool isSensitive;

  FileAnalysisEntry({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256Hash,
    required this.lastModified,
    this.isSensitive = false,
  });

  Map<String, dynamic> toJson() => {
    'path': relativePath,
    'size': sizeBytes,
    'sha256': sha256Hash,
    'modified': lastModified.toIso8601String(),
    'isSensitive': isSensitive,
  };
}

class FolderAnalysisReport {
  final String rootPath;
  final DateTime analyzedAt;
  final int totalFiles;
  final int totalBytes;
  final List<FileAnalysisEntry> files;
  final List<String> sensitiveAlerts;
  final Map<String, int> extensionCounts;

  FolderAnalysisReport({
    required this.rootPath,
    required this.analyzedAt,
    required this.totalFiles,
    required this.totalBytes,
    required this.files,
    required this.sensitiveAlerts,
    required this.extensionCounts,
  });

  Map<String, dynamic> toJson() => {
    'rootPath': rootPath,
    'analyzedAt': analyzedAt.toIso8601String(),
    'totalFiles': totalFiles,
    'totalBytes': totalBytes,
    'sensitiveAlerts': sensitiveAlerts,
    'extensionCounts': extensionCounts,
    'files': files.map((f) => f.toJson()).toList(),
  };

  String toFormattedString() {
    final sb = StringBuffer();
    sb.writeln('====================================================');
    sb.writeln('📁 CYBE LOCAL FOLDER ANALYSIS REPORT');
    sb.writeln('====================================================');
    sb.writeln('Target Path     : $rootPath');
    sb.writeln('Timestamp       : ${analyzedAt.toLocal()}');
    sb.writeln('Total Files     : $totalFiles');
    sb.writeln('Total Size      : ${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB ($totalBytes bytes)');
    sb.writeln('----------------------------------------------------');
    sb.writeln('File Types:');
    extensionCounts.forEach((ext, count) {
      sb.writeln('  • ${ext.isEmpty ? "(no ext)" : ext}: $count files');
    });

    if (sensitiveAlerts.isNotEmpty) {
      sb.writeln('----------------------------------------------------');
      sb.writeln('⚠️ SENSITIVE / SECURITY ADVISORIES (${sensitiveAlerts.length}):');
      for (final alert in sensitiveAlerts) {
        sb.writeln('  [ALERT] $alert');
      }
    } else {
      sb.writeln('----------------------------------------------------');
      sb.writeln('✅ No unencrypted secrets or sensitive patterns flagged.');
    }
    sb.writeln('====================================================');
    return sb.toString();
  }
}

class FolderAnalyzer {
  static const Set<String> _ignoredDirectories = {
    '.git',
    '.dart_tool',
    'build',
    '.gradle',
    'node_modules',
    '.idea',
    '.vscode',
  };

  static const List<String> _sensitiveExtensions = [
    '.env',
    '.pem',
    '.key',
    '.keystore',
    '.jks',
    '.p12',
    '.pfx',
    '.id_rsa',
  ];

  static Future<FolderAnalysisReport> analyze(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist: $directoryPath');
    }

    final entries = <FileAnalysisEntry>[];
    final sensitiveAlerts = <String>[];
    final extCounts = <String, int>{};
    int totalBytes = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final relPath = p.relative(entity.path, from: directoryPath);

      // Skip ignored build and cache directories
      final parts = p.split(relPath);
      if (parts.any((part) => _ignoredDirectories.contains(part))) {
        continue;
      }

      final ext = p.extension(entity.path).toLowerCase();
      extCounts[ext] = (extCounts[ext] ?? 0) + 1;

      try {
        final stat = await entity.stat();
        final bytes = await entity.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        totalBytes += stat.size;

        bool isSensitive = false;
        final baseName = p.basename(entity.path).toLowerCase();

        if (_sensitiveExtensions.contains(ext) || baseName.startsWith('.env')) {
          isSensitive = true;
          sensitiveAlerts.add('Sensitive credential file found: $relPath');
        } else if (bytes.length < 500000) {
          // Check text files for potential leaked private keys
          try {
            final content = utf8.decode(bytes);
            if (content.contains('BEGIN PRIVATE KEY') ||
                content.contains('BEGIN RSA PRIVATE KEY') ||
                content.contains('AIzaSy')) {
              isSensitive = true;
              sensitiveAlerts.add('Private key or Google API key pattern detected in: $relPath');
            }
          } catch (_) {}
        }

        entries.add(FileAnalysisEntry(
          relativePath: relPath,
          sizeBytes: stat.size,
          sha256Hash: hash,
          lastModified: stat.modified,
          isSensitive: isSensitive,
        ));
      } catch (e) {
        // Skip unreadable files
      }
    }

    return FolderAnalysisReport(
      rootPath: directoryPath,
      analyzedAt: DateTime.now(),
      totalFiles: entries.length,
      totalBytes: totalBytes,
      files: entries,
      sensitiveAlerts: sensitiveAlerts,
      extensionCounts: extCounts,
    );
  }
}
