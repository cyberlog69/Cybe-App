import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/mesh_message.dart';
import '../models/peer_info.dart';
import 'mesh_service_interface.dart';

const String _kMulticastAddr = '239.255.0.100';
const int _kDiscoveryPort = 42100;
const int _kBeaconIntervalSec = 1;

class _LanPeer {
  final String id;
  final String alias;
  final String address;
  final int tcpPort;
  final Socket socket;
  DateTime lastSeen;

  _LanPeer({
    required this.id,
    required this.alias,
    required this.address,
    required this.tcpPort,
    required this.socket,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}

/// High-performance cross-platform LAN Mesh service for BitMesh.
/// Uses multi-target UDP broadcast/multicast and TCP framed streams.
class LanMeshService implements MeshServiceInterface {
  LanMeshService._();
  static final LanMeshService instance = LanMeshService._();

  final _messageController = StreamController<MeshMessage>.broadcast();
  final _peersController = StreamController<List<MeshPeerInfo>>.broadcast();

  @override
  Stream<MeshMessage> get incomingMessages => _messageController.stream;
  @override
  Stream<List<MeshPeerInfo>> get discoveredPeers => _peersController.stream;

  final String _nodeId = const Uuid().v4();
  final Set<String> _seenMessageIds = {};
  final Map<String, _LanPeer> _peers = {};
  final List<MeshPeerInfo> _peerList = [];

  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Timer? _beaconTimer;
  Timer? _subnetSweepTimer;
  StreamSubscription<RawSocketEvent>? _udpSub;
  bool _isRunning = false;
  String _nodeAlias = 'CybeNode';
  int _tcpPort = 0;

  String get nodeAlias => _nodeAlias;
  @override
  bool get isRunning => _isRunning;
  @override
  List<MeshPeerInfo> get peers => List.unmodifiable(_peerList);

  static bool get isSupported => true;

  @override
  Future<void> start({required String alias}) async {
    if (_isRunning) return;
    _nodeAlias = alias;
    _isRunning = true;

    try {
      await _startTcpServer();
      await _startUdpDiscovery();
      _startBeacon();
      _triggerSubnetSweep();
      debugPrint('[LanMesh] Service started as "$alias" on port $_tcpPort');
    } catch (e) {
      debugPrint('[LanMesh] Start error: $e');
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _isRunning = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _subnetSweepTimer?.cancel();
    _subnetSweepTimer = null;

    await _udpSub?.cancel();
    _udpSocket?.close();
    _udpSocket = null;

    await _tcpServer?.close();
    _tcpServer = null;

    for (final peer in List<_LanPeer>.from(_peers.values)) {
      try {
        await peer.socket.close();
      } catch (_) {}
    }
    _peers.clear();
    _peerList.clear();
    _seenMessageIds.clear();
    _peersController.add([]);
    debugPrint('[LanMesh] Service stopped');
  }

  Future<void> _startTcpServer() async {
    _tcpServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    _tcpPort = _tcpServer!.port;
    _tcpServer!.listen(_onIncomingTcpConnection);
  }

  Future<void> _startUdpDiscovery() async {
    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _kDiscoveryPort,
      reuseAddress: true,
    );
    _udpSocket!.broadcastEnabled = true;

    try {
      _udpSocket!.multicastHops = 2;
      _udpSocket!.joinMulticast(InternetAddress(_kMulticastAddr));
    } catch (_) {}

    _udpSub = _udpSocket!.listen(_onUdpData);
  }

  void _startBeacon() {
    _beaconTimer = Timer.periodic(
      const Duration(seconds: _kBeaconIntervalSec),
      (_) => _sendBeacon(),
    );
    _sendBeacon();
  }

  Future<List<String>> _getLocalBroadcastAddresses() async {
    final list = <String>['255.255.255.255', _kMulticastAddr];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          final parts = ip.split('.');
          if (parts.length == 4) {
            list.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
          }
        }
      }
    } catch (_) {}
    return list.toSet().toList();
  }

  Future<void> _sendBeacon() async {
    if (_udpSocket == null || !_isRunning) return;
    final beacon = jsonEncode({
      'type': 'beacon',
      'nodeId': _nodeId,
      'alias': _nodeAlias,
      'tcpPort': _tcpPort,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    final bytes = utf8.encode(beacon);

    final targets = await _getLocalBroadcastAddresses();
    for (final target in targets) {
      try {
        _udpSocket!.send(bytes, InternetAddress(target), _kDiscoveryPort);
      } catch (_) {}
    }
  }

  void _triggerSubnetSweep() {
    _subnetSweepTimer?.cancel();
    _subnetSweepTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_isRunning) return;
      await _sweepSubnet();
    });
    _sweepSubnet();
  }

  Future<void> _sweepSubnet() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final beacon = jsonEncode({
        'type': 'beacon',
        'nodeId': _nodeId,
        'alias': _nodeAlias,
        'tcpPort': _tcpPort,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      final bytes = utf8.encode(beacon);

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            final selfLast = int.tryParse(parts[3]) ?? -1;
            for (var i = 1; i <= 254; i++) {
              if (i == selfLast) continue;
              final ip = '$prefix.$i';
              try {
                _udpSocket?.send(bytes, InternetAddress(ip), _kDiscoveryPort);
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }

  void _onUdpData(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udpSocket == null) return;
    final datagram = _udpSocket!.receive();
    if (datagram == null) return;

    try {
      final data = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final remoteNodeId = data['nodeId'] as String? ?? '';
      final alias = data['alias'] as String? ?? 'Unknown';
      final tcpPort = data['tcpPort'] as int?;
      final remoteAddr = datagram.address.address;

      if (remoteNodeId == _nodeId || alias == _nodeAlias) return;
      if (tcpPort == null || tcpPort == 0) return;

      final peerKey = '$remoteAddr:$tcpPort';
      if (_peers.containsKey(peerKey)) {
        _peers[peerKey]!.lastSeen = DateTime.now();
        return;
      }

      _connectToPeer(peerKey, remoteAddr, tcpPort, alias);
    } catch (_) {}
  }

  Future<void> _connectToPeer(
    String peerKey,
    String address,
    int tcpPort,
    String alias,
  ) async {
    if (_peers.containsKey(peerKey)) return;
    try {
      final socket = await Socket.connect(
        address,
        tcpPort,
        timeout: const Duration(seconds: 4),
      );

      _setupSocketListener(socket, isOutbound: true, expectedAlias: alias, address: address, tcpPort: tcpPort);
    } catch (_) {}
  }

  void _onIncomingTcpConnection(Socket socket) {
    _setupSocketListener(socket, isOutbound: false);
  }

  void _setupSocketListener(
    Socket socket, {
    required bool isOutbound,
    String expectedAlias = 'PeerNode',
    String address = '',
    int tcpPort = 0,
  }) {
    final remoteIp = address.isNotEmpty ? address : socket.remoteAddress.address;
    final buffer = <int>[];
    String? assignedPeerKey;

    // Send HELLO handshake instantly over TCP
    final handshake = jsonEncode({
      'type': 'handshake',
      'nodeId': _nodeId,
      'alias': _nodeAlias,
      'tcpPort': _tcpPort,
    });
    final handshakeBytes = utf8.encode('$handshake\n');
    try {
      socket.add(handshakeBytes);
    } catch (_) {}

    socket.listen(
      (chunk) {
        buffer.addAll(chunk);
        while (true) {
          final newlineIndex = buffer.indexOf(10);
          if (newlineIndex == -1) break;
          final lineBytes = buffer.sublist(0, newlineIndex);
          buffer.removeRange(0, newlineIndex + 1);

          final lineStr = utf8.decode(lineBytes).trim();
          if (lineStr.isEmpty) continue;

          try {
            final json = jsonDecode(lineStr) as Map<String, dynamic>;
            final type = json['type'] as String?;

            if (type == 'handshake') {
              final remoteNodeId = json['nodeId'] as String? ?? '';
              final remoteAlias = json['alias'] as String? ?? expectedAlias;
              final remotePort = json['tcpPort'] as int? ?? tcpPort;
              if (remoteNodeId == _nodeId) continue;

              final peerKey = '$remoteIp:$remotePort';
              assignedPeerKey = peerKey;

              final existingPeer = _peers[peerKey];
              if (existingPeer != null && existingPeer.socket != socket) {
                try {
                  existingPeer.socket.close();
                } catch (_) {}
              }

              final peer = _LanPeer(
                id: peerKey,
                alias: remoteAlias,
                address: remoteIp,
                tcpPort: remotePort,
                socket: socket,
              );
              _peers[peerKey] = peer;
              _peerList.removeWhere((p) => p.deviceId == peerKey);
              _peerList.add(MeshPeerInfo(
                deviceId: peerKey,
                name: remoteAlias,
                rssi: 0,
              ));
              _peersController.add(List.from(_peerList));
              debugPrint('[LanMesh] Connected peer registered/updated: $remoteAlias ($peerKey)');
            } else {
              // Standard MeshMessage
              final msg = MeshMessage.fromJson(json);
              _handleIncomingMessage(msg);
            }
          } catch (_) {}
        }
      },
      onDone: () => _removeSocket(assignedPeerKey, socket),
      onError: (_) => _removeSocket(assignedPeerKey, socket),
    );
  }

  void _handleIncomingMessage(MeshMessage msg) {
    if (_seenMessageIds.contains(msg.id)) return;
    _seenMessageIds.add(msg.id);
    if (_seenMessageIds.length > 500) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }

    _messageController.add(msg);

    if (msg.canRelay) {
      _relay(msg.relayed());
    }
  }

  void _removeSocket(String? peerKey, Socket socket) {
    try {
      socket.close();
    } catch (_) {}

    if (peerKey != null && _peers.containsKey(peerKey)) {
      final peer = _peers.remove(peerKey);
      _peerList.removeWhere((p) => p.deviceId == peerKey);
      _peersController.add(List.from(_peerList));
      if (peer != null) {
        debugPrint('[LanMesh] Peer disconnected: ${peer.alias} ($peerKey)');
      }
    }
  }

  Future<void> _relay(MeshMessage msg) async {
    final jsonStr = jsonEncode(msg.toJson());
    final bytes = utf8.encode('$jsonStr\n');

    for (final peer in List<_LanPeer>.from(_peers.values)) {
      try {
        peer.socket.add(bytes);
      } catch (_) {}
    }
  }

  @override
  Future<int> sendMessage({
    required String channelName,
    required String encryptedData,
    required String senderAlias,
  }) async {
    final msg = MeshMessage(
      id: const Uuid().v4(),
      senderAlias: senderAlias,
      channel: channelName,
      encryptedData: encryptedData,
      timestamp: DateTime.now(),
      hops: 0,
      ttl: 5,
      isOwn: true,
    );

    _seenMessageIds.add(msg.id);
    final jsonStr = jsonEncode(msg.toJson());
    final bytes = utf8.encode('$jsonStr\n');

    int delivered = 0;
    for (final peer in List<_LanPeer>.from(_peers.values)) {
      try {
        peer.socket.add(bytes);
        delivered++;
      } catch (e) {
        debugPrint('[LanMesh] Send message error to ${peer.alias}: $e');
      }
    }

    return delivered;
  }

  @override
  void dispose() {
    _messageController.close();
    _peersController.close();
  }
}
