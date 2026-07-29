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
const int _kBeaconIntervalSec = 3;

/// LAN Mesh Service for BitMesh off-grid messenger.
///
/// Uses UDP multicast for peer discovery and TCP for message exchange.
/// Designed as a drop-in alternative to BleMeshService on platforms
/// where BLE is unavailable (e.g. Windows without Bluetooth).
class LanMeshService implements MeshServiceInterface {
  LanMeshService._();
  static final LanMeshService instance = LanMeshService._();

  final _messageController = StreamController<MeshMessage>.broadcast();
  final _peersController = StreamController<List<MeshPeerInfo>>.broadcast();

  @override
  Stream<MeshMessage> get incomingMessages => _messageController.stream;
  @override
  Stream<List<MeshPeerInfo>> get discoveredPeers => _peersController.stream;

  final Set<String> _seenMessageIds = {};
  final Map<String, _LanPeer> _peers = {};
  final List<MeshPeerInfo> _peerList = [];

  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Timer? _beaconTimer;
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
    await _udpSub?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    await _tcpServer?.close();
    _tcpServer = null;
    for (final peer in _peers.values) {
      await peer.socket?.close();
    }
    _peers.clear();
    _peerList.clear();
    _seenMessageIds.clear();
    debugPrint('[LanMesh] Service stopped');
  }

  Future<void> _startTcpServer() async {
    _tcpServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    _tcpPort = _tcpServer!.port;
    _tcpServer!.listen(_onTcpConnection);
  }

  Future<void> _startUdpDiscovery() async {
    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _kDiscoveryPort,
      reuseAddress: true,
    );
    _udpSocket!.multicastHops = 1;
    _udpSocket!.joinMulticast(InternetAddress(_kMulticastAddr));
    _udpSub = _udpSocket!.listen(_onUdpData);
  }

  void _startBeacon() {
    _beaconTimer = Timer.periodic(
      const Duration(seconds: _kBeaconIntervalSec),
      (_) => _sendBeacon(),
    );
    _sendBeacon();
  }

  void _sendBeacon() {
    if (_udpSocket == null) return;
    final beacon = jsonEncode({
      'alias': _nodeAlias,
      'tcpPort': _tcpPort,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _udpSocket!.send(
      utf8.encode(beacon),
      InternetAddress(_kMulticastAddr),
      _kDiscoveryPort,
    );
  }

  void _onUdpData(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udpSocket == null) return;
    final datagram = _udpSocket!.receive();
    if (datagram == null) return;

    try {
      final data = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final alias = data['alias'] as String? ?? 'Unknown';
      final tcpPort = data['tcpPort'] as int?;
      final remoteAddr = datagram.address.address;

      if (tcpPort == null || tcpPort == 0) return;
      if (alias == _nodeAlias) return;

      final peerId = '$remoteAddr:$tcpPort';
      final existing = _peers[peerId];

      if (existing != null) {
        existing.lastSeen = DateTime.now();
        return;
      }

      _connectToPeer(peerId, remoteAddr, tcpPort, alias);
    } catch (e) {
      debugPrint('[LanMesh] Beacon parse error: $e');
    }
  }

  Future<void> _connectToPeer(
    String peerId,
    String address,
    int tcpPort,
    String alias,
  ) async {
    try {
      final socket = await Socket.connect(
        address,
        tcpPort,
        timeout: const Duration(seconds: 5),
      );

      final peer = _LanPeer(
        id: peerId,
        alias: alias,
        address: address,
        tcpPort: tcpPort,
        socket: socket,
      );
      _peers[peerId] = peer;
      _peerList.add(MeshPeerInfo(
        deviceId: peerId,
        name: alias,
        rssi: 0,
      ));
      _peersController.add(List.from(_peerList));

      socket.listen(
        (data) => _onTcpData(peerId, data),
        onDone: () => _onPeerDisconnected(peerId),
        onError: (_) => _onPeerDisconnected(peerId),
      );

      _sendBufferedMessages(peer);

      debugPrint('[LanMesh] Connected to peer: $alias ($address:$tcpPort)');
    } catch (e) {
      _peers.remove(peerId);
      debugPrint('[LanMesh] Connect failed to $address:$tcpPort: $e');
    }
  }

  void _onTcpConnection(Socket socket) {
    final remoteAddr = '${socket.remoteAddress.address}:${socket.remotePort}';
    socket.listen(
      (data) => _onTcpData(remoteAddr, data),
      onDone: () => _onPeerDisconnected(remoteAddr),
      onError: (_) => _onPeerDisconnected(remoteAddr),
    );
  }

  void _onTcpData(String peerId, List<int> data) {
    final msg = MeshMessage.fromBytes(data);
    if (msg == null) return;
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

  Future<void> _relay(MeshMessage msg) async {
    final bytes = msg.toBytes();
    for (final peer in _peers.values) {
      try {
        peer.socket?.add(bytes);
      } catch (_) {}
    }
  }

  void _onPeerDisconnected(String peerId) {
    _peers.remove(peerId);
    _peerList.removeWhere((p) => p.deviceId == peerId);
    _peersController.add(List.from(_peerList));
    debugPrint('[LanMesh] Peer disconnected: $peerId');
  }

  void _sendBufferedMessages(_LanPeer peer) {
    // Future enhancement: buffer messages sent before TCP connection is established
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
    final bytes = msg.toBytes();
    int delivered = 0;
    for (final peer in _peers.values) {
      try {
        peer.socket?.add(bytes);
        delivered++;
      } catch (_) {}
    }
    return delivered;
  }

  @override
  void dispose() {
    _messageController.close();
    _peersController.close();
  }
}

class _LanPeer {
  final String id;
  final String alias;
  final String address;
  final int tcpPort;
  Socket? socket;
  DateTime lastSeen;

  _LanPeer({
    required this.id,
    required this.alias,
    required this.address,
    required this.tcpPort,
    this.socket,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}
