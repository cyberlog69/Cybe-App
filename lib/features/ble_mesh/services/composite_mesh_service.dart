import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mesh_message.dart';
import '../models/peer_info.dart';
import 'mesh_service_interface.dart';
import 'ble_mesh_service.dart';
import 'lan_mesh_service.dart';

/// Composite mesh service that runs both BLE and LAN transports.
///
/// - On **Android**: runs both [BleMeshService] (phone-to-phone) and
///   [LanMeshService] (phone-to-Windows over WiFi) simultaneously.
/// - On **Windows**: runs only [LanMeshService] (no BLE hardware).
///
/// Peers and messages from both transports are merged into single streams.
class CompositeMeshService implements MeshServiceInterface {
  CompositeMeshService._();
  static final CompositeMeshService instance = CompositeMeshService._();

  final _messageController = StreamController<MeshMessage>.broadcast();
  final _peersController = StreamController<List<MeshPeerInfo>>.broadcast();

  @override
  Stream<MeshMessage> get incomingMessages => _messageController.stream;
  @override
  Stream<List<MeshPeerInfo>> get discoveredPeers => _peersController.stream;

  bool _isRunning = false;
  @override
  bool get isRunning => _isRunning;

  final List<MeshPeerInfo> _mergedPeers = [];
  @override
  List<MeshPeerInfo> get peers => List.unmodifiable(_mergedPeers);

  StreamSubscription<MeshMessage>? _bleMsgSub;
  StreamSubscription<MeshMessage>? _lanMsgSub;
  StreamSubscription<List<MeshPeerInfo>>? _blePeerSub;
  StreamSubscription<List<MeshPeerInfo>>? _lanPeerSub;

  bool get _shouldRunBle =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;

  @override
  Future<void> start({required String alias}) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      // Always start LAN (works on all platforms with networking)
      await LanMeshService.instance.start(alias: alias);
      _lanMsgSub = LanMeshService.instance.incomingMessages.listen(_onMessage);
      _lanPeerSub = LanMeshService.instance.discoveredPeers.listen(_onPeersChanged);

      // Start BLE on platforms that support it
      if (_shouldRunBle) {
        try {
          await BleMeshService.instance.start(alias: alias);
          _bleMsgSub = BleMeshService.instance.incomingMessages.listen(_onMessage);
          _blePeerSub = BleMeshService.instance.discoveredPeers.listen(_onPeersChanged);
        } catch (e) {
          debugPrint('[Composite] BLE not available, LAN only: $e');
        }
      }

      // Emit initial peer list
      _rebuildPeerList();
      debugPrint('[Composite] Service started (LAN: yes, BLE: $_shouldRunBle)');
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _isRunning = false;
    await _bleMsgSub?.cancel();
    await _lanMsgSub?.cancel();
    await _blePeerSub?.cancel();
    await _lanPeerSub?.cancel();
    _bleMsgSub = null;
    _lanMsgSub = null;
    _blePeerSub = null;
    _lanPeerSub = null;
    await BleMeshService.instance.stop();
    await LanMeshService.instance.stop();
    _mergedPeers.clear();
    debugPrint('[Composite] Service stopped');
  }

  void _onMessage(MeshMessage msg) {
    _messageController.add(msg);
  }

  void _onPeersChanged(List<MeshPeerInfo> _) {
    _rebuildPeerList();
  }

  void _rebuildPeerList() {
    final seen = <String>{};
    _mergedPeers.clear();

    for (final p in LanMeshService.instance.peers) {
      if (seen.add(p.deviceId)) _mergedPeers.add(p);
    }
    for (final p in BleMeshService.instance.peers) {
      if (seen.add(p.deviceId)) _mergedPeers.add(p);
    }

    _peersController.add(List.from(_mergedPeers));
  }

  @override
  Future<int> sendMessage({
    required String channelName,
    required String encryptedData,
    required String senderAlias,
  }) async {
    int count = 0;
    count += await BleMeshService.instance.sendMessage(
      channelName: channelName,
      encryptedData: encryptedData,
      senderAlias: senderAlias,
    );
    count += await LanMeshService.instance.sendMessage(
      channelName: channelName,
      encryptedData: encryptedData,
      senderAlias: senderAlias,
    );
    return count;
  }

  @override
  void dispose() {
    _messageController.close();
    _peersController.close();
  }
}
