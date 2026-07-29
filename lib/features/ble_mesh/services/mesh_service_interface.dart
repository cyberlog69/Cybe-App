import 'dart:async';
import '../models/mesh_message.dart';
import '../models/peer_info.dart';

/// Common interface for mesh transport services (BLE or LAN).
abstract class MeshServiceInterface {
  Stream<MeshMessage> get incomingMessages;
  Stream<List<MeshPeerInfo>> get discoveredPeers;
  bool get isRunning;
  List<MeshPeerInfo> get peers;

  Future<void> start({required String alias});
  Future<void> stop();
  Future<int> sendMessage({
    required String channelName,
    required String encryptedData,
    required String senderAlias,
  });
  void dispose();
}
