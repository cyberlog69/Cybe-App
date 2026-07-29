import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/mesh_message.dart';
import '../models/peer_info.dart';
import 'mesh_service_interface.dart';

/// Cybe BitMesh — BLE characteristic UUIDs
const String _kTxCharUuidPrefix = '6e400002'; // We write to peers
const String _kRxCharUuidPrefix = '6e400003'; // We notify on this

/// BLE Mesh Service for BitMesh off-grid messenger.
///
/// - Scans for nearby Cybe nodes continuously.
/// - Connects to discovered peers and subscribes to their RX characteristic.
/// - Writes outgoing messages to all connected peers via TX characteristic.
/// - Relays received messages to other peers (store-and-forward flood mesh).
/// - Deduplicates messages by UUID to prevent relay loops.
class BleMeshService implements MeshServiceInterface {
  BleMeshService._();
  static final BleMeshService instance = BleMeshService._();

  // Streams
  final _messageController = StreamController<MeshMessage>.broadcast();
  final _peersController = StreamController<List<MeshPeerInfo>>.broadcast();

  @override
  Stream<MeshMessage> get incomingMessages => _messageController.stream;
  @override
  Stream<List<MeshPeerInfo>> get discoveredPeers => _peersController.stream;

  // State
  final Map<String, BluetoothDevice> _connectedPeers = {};
  final Map<String, BluetoothCharacteristic> _txChars = {};
  final Set<String> _seenMessageIds = {};
  final List<MeshPeerInfo> _peers = [];

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isRunning = false;
  String _nodeAlias = 'CybeNode';
  String get nodeAlias => _nodeAlias;

  // Platform capability
  /// Whether BLE scanning is supported on this platform.
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  @override
  bool get isRunning => _isRunning;
  @override
  List<MeshPeerInfo> get peers => List.unmodifiable(_peers);


  /// Start the BitMesh service: begin scanning for nearby Cybe nodes.
  @override
  Future<void> start({required String alias}) async {
    if (_isRunning) return;
    _nodeAlias = alias;

    // Guard: flutter_blue_plus only works on Android/iOS/macOS/Linux at runtime
    if (!isSupported) {
      debugPrint('[BitMesh] BLE not supported on this platform (${Platform.operatingSystem})');
      throw UnsupportedError('BLE mesh is not supported on ${Platform.operatingSystem}. Use Android or iOS.');
    }

    _isRunning = true;

    try {
      // Check BLE support
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('[BitMesh] Bluetooth not supported on this device');
        _isRunning = false;
        return;
      }

      // Turn on BT if off on Android
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }

      // Wait for BT to be ready
      try {
        await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // On Windows the adapter state may not emit 'on' reliably;
        // proceed with scanning anyway.
        if (!Platform.isWindows) rethrow;
      }

      await _startScanning();
      debugPrint('[BitMesh] Service started as "$alias"');
    } catch (e) {
      debugPrint('[BitMesh] Start error: $e');
      _isRunning = false;
      rethrow;
    }

  }

  /// Stop scanning and disconnect from all peers
  @override
  Future<void> stop() async {
    _isRunning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
    for (final device in _connectedPeers.values) {
      await device.disconnect();
    }
    _connectedPeers.clear();
    _txChars.clear();
    _peers.clear();
    debugPrint('[BitMesh] Service stopped');
  }

  Future<void> _startScanning() async {
    await FlutterBluePlus.startScan(
      continuousUpdates: true,
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _peers.clear();
      for (final r in results) {
        _peers.add(MeshPeerInfo(
          deviceId: r.device.remoteId.str,
          name: r.device.platformName.isNotEmpty
              ? r.device.platformName
              : 'Unknown',
          rssi: r.rssi,
        ));
        // Auto-connect to potential Cybe nodes
        if (!_connectedPeers.containsKey(r.device.remoteId.str)) {
          _connectToPeer(r.device);
        }
      }
      _peersController.add(List.from(_peers));
    });
  }

  Future<void> _connectToPeer(BluetoothDevice device) async {
    final id = device.remoteId.str;
    try {
      await device.connect(timeout: const Duration(seconds: 10));

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedPeers.remove(id);
          _txChars.remove(id);
          debugPrint('[BitMesh] Peer disconnected: $id');
        }
      });

      // Discover services and verify Cybe service presence
      await device.discoverServices();
      bool foundCybeService = false;
      final services = device.servicesList;
      for (final svc in services) {
        if (svc.serviceUuid.str.toLowerCase().startsWith('6e400001')) {
          for (final char in svc.characteristics) {
            final charUuid = char.characteristicUuid.str.toLowerCase();
            if (charUuid.startsWith(_kTxCharUuidPrefix)) {
              _txChars[id] = char;
              foundCybeService = true;
            } else if (charUuid.startsWith(_kRxCharUuidPrefix)) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((data) => _onDataReceived(data));
              foundCybeService = true;
            }
          }
        }
      }

      if (foundCybeService) {
        _connectedPeers[id] = device;
        debugPrint('[BitMesh] Connected to Cybe peer: $id');
      } else {
        await device.disconnect();
        debugPrint('[BitMesh] Disconnected non-Cybe device: $id');
      }
    } catch (e) {
      _connectedPeers.remove(id);
      debugPrint('[BitMesh] Connect failed for $id: $e');
    }
  }

  void _onDataReceived(List<int> data) {
    final msg = MeshMessage.fromBytes(data);
    if (msg == null) return;
    if (_seenMessageIds.contains(msg.id)) return; // dedup
    _seenMessageIds.add(msg.id);
    if (_seenMessageIds.length > 500) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }

    _messageController.add(msg);

    // Relay if TTL allows
    if (msg.canRelay) {
      _relay(msg.relayed());
    }
  }

  Future<void> _relay(MeshMessage msg) async {
    final bytes = msg.toBytes();
    for (final char in _txChars.values) {
      try {
        await char.write(bytes, withoutResponse: true);
      } catch (_) {}
    }
  }

  /// Send a message to all connected peers
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

    // Mark as seen so we don't relay our own message back to ourselves
    _seenMessageIds.add(msg.id);

    final bytes = msg.toBytes();
    int delivered = 0;
    for (final char in _txChars.values) {
      try {
        await char.write(bytes, withoutResponse: true);
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
