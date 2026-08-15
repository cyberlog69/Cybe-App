import 'dart:io';
import 'package:test/test.dart';
import '../lib/src/folder_analyzer.dart';
import '../lib/src/mesh_relay.dart';

void main() {
  group('FolderAnalyzer Tests', () {
    test('analyzes directory and counts files & hashes', () async {
      final tempDir = await Directory.systemTemp.createTemp('relay_test_');
      try {
        final testFile1 = File('${tempDir.path}/hello.txt');
        await testFile1.writeAsString('Hello BitMesh Relay');

        final testFile2 = File('${tempDir.path}/secret.env');
        await testFile2.writeAsString('SECRET_KEY=123456');

        final report = await FolderAnalyzer.analyze(tempDir.path);

        expect(report.totalFiles, equals(2));
        expect(report.sensitiveAlerts.isNotEmpty, isTrue);
        expect(report.extensionCounts['.txt'], equals(1));
        expect(report.extensionCounts['.env'], equals(1));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('BitMeshRelayServer Tests', () {
    test('starts and stops gracefully on random port', () async {
      final relay = BitMeshRelayServer(
        relayAlias: 'TestRelay',
        configuredPort: 0,
      );

      await relay.start();
      expect(relay.isRunning, isTrue);
      expect(relay.port > 0, isTrue);

      await relay.stop();
      expect(relay.isRunning, isFalse);
    });
  });
}
