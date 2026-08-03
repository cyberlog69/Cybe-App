import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../../security_logs/services/security_log_service.dart';
import '../models/antivirus_threat.dart';

enum ScanMode { quick, full, custom }

class AntivirusScannerService {
  static final _knownMalwareHashes = <String>{
    // EICAR Standard Test Hash (SHA-256)
    '275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f',
    '131f95c51cc819465fa1797f6ccacf9d494aaaff46fa3eac73ae63ffbdfd8267',
  };

  static final _suspiciousDoubleExts = RegExp(
    r'\.(pdf|docx|xlsx|png|jpg|mp4|zip|rar)\.(exe|vbs|bat|cmd|scr|js|ps1|apk)$',
    caseSensitive: false,
  );

  static final _ransomwareExts = RegExp(
    r'\.(locked|crypto|wnry|clop|lokf|readme_to_decrypt|enc|payme)$',
    caseSensitive: false,
  );

  /// Resolves platform-specific scan directories (Windows, Linux, Android, macOS)
  static Future<List<Directory>> getPlatformScanDirectories(ScanMode mode) async {
    final dirs = <Directory>[];

    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        final temp = Platform.environment['TEMP'];
        if (userProfile != null) {
          dirs.add(Directory('$userProfile\\Downloads'));
          if (mode == ScanMode.full) {
            dirs.add(Directory('$userProfile\\Desktop'));
            dirs.add(Directory('$userProfile\\AppData\\Local\\Temp'));
          }
        }
        if (temp != null && mode == ScanMode.full) {
          dirs.add(Directory(temp));
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '/home';
        dirs.add(Directory('$home/Downloads'));
        dirs.add(Directory('/tmp'));
        if (mode == ScanMode.full) {
          dirs.add(Directory('$home/.local'));
        }
      } else if (Platform.isAndroid) {
        dirs.add(Directory('/sdcard/Download'));
        dirs.add(Directory('/storage/emulated/0/Download'));
        if (mode == ScanMode.full) {
          dirs.add(Directory('/storage/emulated/0/Documents'));
        }
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? '/Users';
        dirs.add(Directory('$home/Downloads'));
        dirs.add(Directory('/tmp'));
      }
    } catch (_) {}

    return dirs.where((d) => d.existsSync()).toList();
  }

  /// Scans a single file or entire directory streamingly with progress feedback
  static Stream<ScanProgress> scanTarget({
    required ScanMode mode,
    Directory? customDir,
    File? singleFile,
    required List<AntivirusThreat> threatsFoundList,
  }) async* {
    threatsFoundList.clear();
    int scannedCount = 0;
    final List<File> filesToScan = [];

    if (singleFile != null && await singleFile.exists()) {
      filesToScan.add(singleFile);
    } else if (customDir != null && await customDir.exists()) {
      filesToScan.addAll(await _collectFiles(customDir, maxDepth: mode == ScanMode.quick ? 2 : 5));
    } else {
      final dirs = await getPlatformScanDirectories(mode);
      for (final dir in dirs) {
        filesToScan.addAll(await _collectFiles(dir, maxDepth: mode == ScanMode.quick ? 2 : 4));
      }
    }

    final totalFiles = filesToScan.isEmpty ? 1 : filesToScan.length;

    for (int i = 0; i < filesToScan.length; i++) {
      final file = filesToScan[i];
      scannedCount++;

      try {
        final threat = await inspectFile(file);
        if (threat != null) {
          threatsFoundList.add(threat);
          await SecurityLogService.logEvent(
            title: 'ANTIVIRUS DETECTED THREAT: ${threat.threatName}',
            message: 'Malware flagged at ${threat.filePath}. Category: ${threat.threatCategory}.',
            severity: 'critical',
            category: 'Malware',
          );
        }
      } catch (_) {}

      final percent = (scannedCount / totalFiles).clamp(0.0, 1.0);
      yield ScanProgress(
        filesScanned: scannedCount,
        threatsFound: threatsFoundList.length,
        currentFile: file.path,
        progressPercent: percent,
        isCompleted: i == filesToScan.length - 1,
      );
    }

    yield ScanProgress(
      filesScanned: scannedCount,
      threatsFound: threatsFoundList.length,
      currentFile: 'Scan Completed',
      progressPercent: 1.0,
      isCompleted: true,
    );
  }

  static Future<List<File>> _collectFiles(Directory dir, {int maxDepth = 3}) async {
    final list = <File>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final size = await entity.length().catchError((_) => 0);
          if (size > 0 && size < 150 * 1024 * 1024) {
            // Cap at 150MB per file to maintain sub-second scan speeds
            list.add(entity);
          }
        }
        if (list.length >= 800) break; // Maximum 800 files per quick scan pass
      }
    } catch (_) {}
    return list;
  }

  /// Multi-Engine Threat Inspector: Signature Hash, Extension Heuristics, Pattern Matching
  static Future<AntivirusThreat?> inspectFile(File file) async {
    final path = file.path;
    final name = file.path.split(Platform.pathSeparator).last;
    final size = await file.length().catchError((_) => 0);

    // 1. Ransomware Extension Detection
    if (_ransomwareExts.hasMatch(name)) {
      return AntivirusThreat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: path,
        fileName: name,
        fileSizeBytes: size,
        threatName: 'Ransomware Encrypted Payload',
        threatCategory: 'Ransomware',
        threatSeverity: 'critical',
        signatureMatch: 'Ransomware File Extension',
        detectedAt: DateTime.now(),
      );
    }

    // 2. Suspicious Double Extension Masking
    if (_suspiciousDoubleExts.hasMatch(name)) {
      return AntivirusThreat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: path,
        fileName: name,
        fileSizeBytes: size,
        threatName: 'Obfuscated Executable Dropper',
        threatCategory: 'Trojan / Dropper',
        threatSeverity: 'high',
        signatureMatch: 'Double Extension Masking',
        detectedAt: DateTime.now(),
      );
    }

    // 3. Binary & Content Heuristics Probe
    try {
      final bytes = await file.readAsBytes();

      // Check SHA-256 Signature Hash
      final digest = sha256.convert(bytes).toString();
      if (_knownMalwareHashes.contains(digest)) {
        return AntivirusThreat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: path,
          fileName: name,
          fileSizeBytes: size,
          threatName: 'Known Malicious Hash Match',
          threatCategory: 'Trojan / Malware',
          threatSeverity: 'critical',
          signatureMatch: 'SHA256: ${digest.substring(0, 12)}...',
          detectedAt: DateTime.now(),
        );
      }

      // Read String Content for Heuristics
      final content = String.fromCharCodes(bytes.take(4096));

      // EICAR Standard Test File
      if (content.contains('EICAR-STANDARD-ANTIVIRUS-TEST-FILE')) {
        return AntivirusThreat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: path,
          fileName: name,
          fileSizeBytes: size,
          threatName: 'EICAR Standard Antivirus Test Payload',
          threatCategory: 'Test Vector',
          threatSeverity: 'medium',
          signatureMatch: 'EICAR Standard Signature',
          detectedAt: DateTime.now(),
        );
      }

      // Powershell / Reverse Shell / WebShell Heuristic Patterns
      if (content.contains('powershell -enc') || content.contains('powershell -e ')) {
        return AntivirusThreat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: path,
          fileName: name,
          fileSizeBytes: size,
          threatName: 'Encoded PowerShell Script Execution',
          threatCategory: 'Reverse Shell / Script Host',
          threatSeverity: 'critical',
          signatureMatch: 'Powershell Encoded Command',
          detectedAt: DateTime.now(),
        );
      }

      if (content.contains('com.metasploit.stage') || content.contains('meterpreter')) {
        return AntivirusThreat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: path,
          fileName: name,
          fileSizeBytes: size,
          threatName: 'Metasploit Meterpreter Reverse Shell Payload',
          threatCategory: 'Spyware / Remote Access Tool',
          threatSeverity: 'critical',
          signatureMatch: 'Metasploit Stage Signature',
          detectedAt: DateTime.now(),
        );
      }

      if (content.contains('/bin/sh -i') || content.contains('nc -e /bin/sh')) {
        return AntivirusThreat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: path,
          fileName: name,
          fileSizeBytes: size,
          threatName: 'Linux Reverse Shell Script',
          threatCategory: 'Backdoor',
          threatSeverity: 'critical',
          signatureMatch: 'Netcat / Shell Pipe Command',
          detectedAt: DateTime.now(),
        );
      }
    } catch (_) {}

    return null;
  }
}
