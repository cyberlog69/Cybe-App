import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

const String kMulticastAddr = '239.255.0.100';
const int kDiscoveryPort = 42100;
const int kBeaconIntervalSec = 2;

class RelayPeer {
  final String id;
  final String alias;
  final String address;
  final int tcpPort;
  final Socket socket;
  DateTime lastSeen;

  RelayPeer({
    required this.id,
    required this.alias,
    required this.address,
    required this.tcpPort,
    required this.socket,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}

class BitMeshRelayServer {
  final String relayAlias;
  final int configuredPort;
  final void Function(String message)? onLog;
  final void Function(Map<String, dynamic> msg)? onMessageRelayed;
  final void Function(List<RelayPeer> peers)? onPeersChanged;

  final String _nodeId = _generateNodeId();
  final Set<String> _seenMessageIds = {};
  final Map<String, RelayPeer> _peers = {};

  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;
  StreamSubscription<RawSocketEvent>? _udpSub;
  bool _isRunning = false;
  int _actualTcpPort = 0;
  int _relayedCount = 0;

  BitMeshRelayServer({
    this.relayAlias = 'BitMesh-Desktop-Relay',
    this.configuredPort = 0,
    this.onLog,
    this.onMessageRelayed,
    this.onPeersChanged,
  });

  bool get isRunning => _isRunning;
  int get port => _actualTcpPort;
  int get relayedCount => _relayedCount;
  List<RelayPeer> get connectedPeers => _peers.values.toList();

  static String _generateNodeId() {
    final rand = DateTime.now().microsecondsSinceEpoch.toString() + Platform.localHostname;
    return sha256.convert(utf8.encode(rand)).toString().substring(0, 16);
  }

  void _log(String text) {
    if (onLog != null) {
      onLog!('[BitMesh Relay] $text');
    } else {
      stdout.writeln('[BitMesh Relay] $text');
    }
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      await _startTcpServer();
      await _startUdpDiscovery();
      _startBeacon();
      _startPeerCleanup();
      _log('Relay daemon active as "$relayAlias" [ID: $_nodeId] listening on TCP port $_actualTcpPort');
    } catch (e) {
      _log('Failed to start relay: $e');
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    await _udpSub?.cancel();
    _udpSocket?.close();
    _udpSocket = null;

    await _tcpServer?.close();
    _tcpServer = null;

    for (final peer in List<RelayPeer>.from(_peers.values)) {
      try {
        await peer.socket.close();
      } catch (_) {}
    }
    _peers.clear();
    _seenMessageIds.clear();
    onPeersChanged?.call([]);
    _log('Relay server stopped.');
  }

  Future<void> _startTcpServer() async {
    _tcpServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      configuredPort,
    );
    _actualTcpPort = _tcpServer!.port;
    _tcpServer!.listen(_onIncomingTcpConnection, onError: (e) {
      _log('TCP Server error: $e');
    });
  }

  Future<void> _startUdpDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kDiscoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );

      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.multicastLoopback = false;

      final mAddr = InternetAddress(kMulticastAddr);
      try {
        _udpSocket!.joinMulticast(mAddr);
      } catch (e) {
        _log('Multicast join note: $e (Broadcasting enabled)');
      }

      _udpSub = _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            _handleUdpDatagram(dg);
          }
        }
      });
    } catch (e) {
      _log('UDP discovery warning: $e. Falling back to TCP relay.');
    }
  }

  void _startBeacon() {
    _beaconTimer = Timer.periodic(const Duration(seconds: kBeaconIntervalSec), (_) {
      if (!_isRunning || _udpSocket == null) return;

      final beacon = jsonEncode({
        'type': 'beacon',
        'id': _nodeId,
        'alias': relayAlias,
        'tcpPort': _actualTcpPort,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'isRelay': true,
      });

      final bytes = utf8.encode(beacon);
      try {
        _udpSocket!.send(bytes, InternetAddress(kMulticastAddr), kDiscoveryPort);
        _udpSocket!.send(bytes, InternetAddress('255.255.255.255'), kDiscoveryPort);
      } catch (_) {}
    });
  }

  void _startPeerCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final stalePeers = <String>[];

      for (final entry in _peers.entries) {
        if (now.difference(entry.value.lastSeen).inSeconds > 15) {
          stalePeers.add(entry.key);
        }
      }

      for (final id in stalePeers) {
        final peer = _peers.remove(id);
        if (peer != null) {
          _log('Peer timed out / disconnected: ${peer.alias} (${peer.address})');
          try {
            peer.socket.destroy();
          } catch (_) {}
        }
      }

      if (stalePeers.isNotEmpty) {
        onPeersChanged?.call(connectedPeers);
      }
    });
  }

  void _handleUdpDatagram(Datagram dg) {
    try {
      final text = utf8.decode(dg.data);
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (json['type'] == 'beacon') {
        final peerId = json['id'] as String?;
        final alias = json['alias'] as String? ?? 'Node';
        final tcpPort = json['tcpPort'] as int?;

        if (peerId == null || peerId == _nodeId || tcpPort == null) return;

        // If we don't already have an active TCP connection to this peer, connect
        if (!_peers.containsKey(peerId)) {
          _connectToPeer(peerId, alias, dg.address.address, tcpPort);
        } else {
          _peers[peerId]?.lastSeen = DateTime.now();
        }
      }
    } catch (_) {}
  }

  Future<void> _connectToPeer(String peerId, String alias, String address, int tcpPort) async {
    try {
      final socket = await Socket.connect(address, tcpPort, timeout: const Duration(seconds: 4));
      final peer = RelayPeer(
        id: peerId,
        alias: alias,
        address: address,
        tcpPort: tcpPort,
        socket: socket,
      );

      _peers[peerId] = peer;
      _log('Connected to peer: $alias ($address:$tcpPort)');
      onPeersChanged?.call(connectedPeers);

      _setupSocketStream(peer);
    } catch (e) {
      // Connect failed or port closed
    }
  }

  void _onIncomingTcpConnection(Socket socket) {
    final remoteAddress = socket.remoteAddress.address;
    final tempId = 'conn_${socket.remotePort}_${DateTime.now().millisecondsSinceEpoch}';

    final peer = RelayPeer(
      id: tempId,
      alias: 'Mobile-Node-$remoteAddress',
      address: remoteAddress,
      tcpPort: socket.remotePort,
      socket: socket,
    );

    _peers[tempId] = peer;
    _log('Inbound connection from mobile device: $remoteAddress:${socket.remotePort}');
    onPeersChanged?.call(connectedPeers);

    _setupSocketStream(peer);
  }

  void _setupSocketStream(RelayPeer peer) {
    final buffer = <int>[];

    peer.socket.listen(
      (data) {
        peer.lastSeen = DateTime.now();
        buffer.addAll(data);

        // Process length-prefixed frames: [4-byte length][JSON payload]
        while (buffer.length >= 4) {
          final bd = ByteData.sublistView(Uint8List.fromList(buffer.sublist(0, 4)));
          final frameLen = bd.getUint32(0);

          if (buffer.length >= 4 + frameLen) {
            final payloadBytes = buffer.sublist(4, 4 + frameLen);
            buffer.removeRange(0, 4 + frameLen);

            _handleIncomingFrame(payloadBytes, peer);
          } else {
            break;
          }
        }
      },
      onError: (e) {
        _removePeer(peer.id);
      },
      onDone: () {
        _removePeer(peer.id);
      },
      cancelOnError: true,
    );
  }

  void _removePeer(String id) {
    final peer = _peers.remove(id);
    if (peer != null) {
      _log('Peer closed connection: ${peer.alias} (${peer.address})');
      try {
        peer.socket.destroy();
      } catch (_) {}
      onPeersChanged?.call(connectedPeers);
    }
  }

  void _handleIncomingFrame(List<int> bytes, RelayPeer sourcePeer) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'message') {
        final msgId = json['id'] as String?;
        if (msgId == null || _seenMessageIds.contains(msgId)) return;

        _seenMessageIds.add(msgId);
        if (_seenMessageIds.length > 5000) {
          _seenMessageIds.remove(_seenMessageIds.first);
        }

        final from = json['from'] as String? ?? 'Unknown';
        final ch = json['ch'] as String? ?? 'public';
        final hops = json['hops'] as int? ?? 0;
        final ttl = json['ttl'] as int? ?? 5;

        _log('Relaying message [$msgId] from "$from" on channel #$ch (Hops: $hops/$ttl)');

        // Prepare relayed copy with incremented hops
        final relayedJson = Map<String, dynamic>.from(json);
        relayedJson['hops'] = hops + 1;
        relayedJson['relayedBy'] = relayAlias;

        _relayedCount++;
        onMessageRelayed?.call(relayedJson);

        if (hops + 1 < ttl) {
          _broadcastFrame(utf8.encode(jsonEncode(relayedJson)), excludeId: sourcePeer.id);
        }
      }
    } catch (e) {
      _log('Error parsing frame: $e');
    }
  }

  /// Broadcast a payload directly across all connected BitMesh peers
  void broadcastMessage({
    required String channel,
    required String plaintextOrData,
    String? customFrom,
  }) {
    final msg = {
      'type': 'message',
      'id': 'relay_${DateTime.now().millisecondsSinceEpoch}',
      'from': customFrom ?? relayAlias,
      'ch': channel,
      'data': plaintextOrData,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'hops': 0,
      'ttl': 5,
      'isRelayBroadcast': true,
    };

    _seenMessageIds.add(msg['id'] as String);
    final bytes = utf8.encode(jsonEncode(msg));
    _broadcastFrame(bytes);
    _log('Injected broadcast message on #$channel: "$plaintextOrData"');
  }

  void _broadcastFrame(List<int> payloadBytes, {String? excludeId}) {
    final frame = BytesBuilder();
    final header = ByteData(4)..setUint32(0, payloadBytes.length);
    frame.add(header.buffer.asUint8List());
    frame.add(payloadBytes);
    final frameBytes = frame.toBytes();

    for (final peer in _peers.values) {
      if (peer.id != excludeId) {
        try {
          peer.socket.add(frameBytes);
        } catch (_) {}
      }
    }
  }
}
