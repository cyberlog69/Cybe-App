import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import '../lib/src/mesh_relay.dart';
import '../lib/src/folder_analyzer.dart';
import '../lib/src/github_sync.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('alias', abbr: 'a', help: 'Node alias name for this BitMesh relay', defaultsTo: 'CybeRelay-${Platform.localHostname}')
    ..addOption('port', abbr: 'p', help: 'TCP listening port for mesh socket connections (0 for auto)', defaultsTo: '42101')
    ..addOption('analyze-dir', abbr: 'd', help: 'Local folder path to analyze on startup and monitor', defaultsTo: '.')
    ..addOption('github-repo', abbr: 'r', help: 'GitHub repository to watch for updates', defaultsTo: 'cyberlog69/Cybe-App')
    ..addOption('interval', abbr: 'i', help: 'Update check interval in minutes', defaultsTo: '15')
    ..addOption('token', abbr: 't', help: 'GitHub personal access token (optional, for higher rate limits)')
    ..addFlag('daemon', help: 'Run in non-interactive daemon mode', defaultsTo: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help menu');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Argument error: $e\n');
    stdout.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] == true) {
    _printBanner();
    stdout.writeln('Usage: dart run bin/cybe_relay.dart [options]\n');
    stdout.writeln(parser.usage);
    exit(0);
  }

  _printBanner();

  final alias = args['alias'] as String;
  final port = int.tryParse(args['port'] as String) ?? 42101;
  final analyzeDir = args['analyze-dir'] as String;
  final repo = args['github-repo'] as String;
  final intervalMin = int.tryParse(args['interval'] as String) ?? 15;
  final token = args['token'] as String?;
  final isDaemon = args['daemon'] as bool;

  stdout.writeln('🚀 Initializing Cybe BitMesh Relay & Sync Daemon on ${Platform.operatingSystem.toUpperCase()}...');
  stdout.writeln('----------------------------------------------------');

  // 1. Run Local Folder Analysis
  stdout.writeln('📁 Analyzing folder: "$analyzeDir" ...');
  try {
    final report = await FolderAnalyzer.analyze(analyzeDir);
    stdout.writeln(report.toFormattedString());
  } catch (e) {
    stdout.writeln('⚠️ Folder analysis skipped: $e\n');
  }

  // 2. Start BitMesh Relay Server
  final relay = BitMeshRelayServer(
    relayAlias: alias,
    configuredPort: port,
    onLog: (msg) => stdout.writeln(msg),
    onMessageRelayed: (msg) {
      stdout.writeln('⚡ [PACKET RELAYED] Channel: #${msg['ch']} | From: ${msg['from']} | Hops: ${msg['hops']}');
    },
    onPeersChanged: (peers) {
      stdout.writeln('👥 Connected Mobile Nodes (${peers.length}): ${peers.map((p) => "${p.alias} (${p.address})").join(", ")}');
    },
  );

  await relay.start();

  // 3. Start GitHub Sync Engine
  final github = GitHubSyncEngine(
    repository: repo,
    gitHubToken: token,
    relayServer: relay,
    onLog: (msg) => stdout.writeln(msg),
    onUpdateFound: (update) {
      stdout.writeln('\n🔔 ====================================================');
      stdout.writeln('🔔 NEW GITHUB UPDATE READY: ${update.latestTag}');
      stdout.writeln('🔔 Title: ${update.releaseName}');
      if (update.apkDownloadUrl != null) {
        stdout.writeln('🔔 Direct APK: ${update.apkDownloadUrl}');
      }
      stdout.writeln('🔔 ====================================================\n');
    },
  );

  github.startPolling(interval: Duration(minutes: intervalMin));

  stdout.writeln('\n====================================================');
  stdout.writeln('🟢 BitMesh Relay Node is RUNNING & DISCOVERABLE');
  stdout.writeln('   • Relay Alias : $alias');
  stdout.writeln('   • Local Port  : ${relay.port}');
  stdout.writeln('   • Multicast   : $kMulticastAddr:$kDiscoveryPort');
  stdout.writeln('   • GitHub Watch: $repo');
  stdout.writeln('====================================================');
  stdout.writeln('Commands: [b] Broadcast Message | [a] Re-analyze Folder | [u] Check GitHub Updates | [q] Quit\n');

  // Handle graceful shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nStopping relay service...');
    await relay.stop();
    github.stopPolling();
    exit(0);
  });

  if (!isDaemon && stdin.hasTerminal) {
    stdin.lineMode = true;
    stdin.listen((bytes) async {
      final input = utf8.decode(bytes).trim();
      if (input.toLowerCase() == 'q') {
        stdout.writeln('Exiting...');
        await relay.stop();
        github.stopPolling();
        exit(0);
      } else if (input.toLowerCase() == 'u') {
        stdout.writeln('Checking GitHub updates manually...');
        await github.checkUpdates();
      } else if (input.toLowerCase() == 'a') {
        stdout.writeln('Re-analyzing folder: $analyzeDir ...');
        final r = await FolderAnalyzer.analyze(analyzeDir);
        stdout.writeln(r.toFormattedString());
      } else if (input.toLowerCase() == 'b') {
        stdout.write('Enter broadcast message for mobile nodes: ');
        final msg = stdin.readLineSync() ?? '';
        if (msg.isNotEmpty) {
          relay.broadcastMessage(channel: 'cybe-public', plaintextOrData: msg);
        }
      }
    });
  } else {
    // Keep process alive in background
    await Completer<void>().future;
  }
}

void _printBanner() {
  stdout.writeln(r'''
  ██████╗██╗   ██╗██████╗ ███████╗    ██████╗ ███████╗██╗      █████╗ ██╗   ██╗
 ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝    ██╔══██╗██╔════╝██║     ██╔══██╗╚██╗ ██╔╝
 ██║      ╚████╔╝ ██████╔╝█████╗      ██████╔╝█████╗  ██║     ███████║ ╚████╔╝ 
 ██║       ╚██╔╝  ██╔══██╗██╔══╝      ██╔══██╗██╔══╝  ██║     ██╔══██║  ╚██╔╝  
 ╚██████╗   ██║   ██████╔╝███████╗    ██║  ██║███████╗███████╗██║  ██║   ██║   
  ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝    ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝   
       BitMesh Relay Node & GitHub Updater Daemon (Windows / Linux)
''');
}
