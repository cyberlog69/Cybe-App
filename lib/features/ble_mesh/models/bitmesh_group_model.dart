import 'package:uuid/uuid.dart';

class BitmeshGroupRoom {
  final String id;
  final String roomName;
  final String sessionKey; // AES-256 group session key
  final List<String> memberPeerIds;
  final DateTime createdAt;

  const BitmeshGroupRoom({
    required this.id,
    required this.roomName,
    required this.sessionKey,
    required this.memberPeerIds,
    required this.createdAt,
  });

  factory BitmeshGroupRoom.create(String name) {
    return BitmeshGroupRoom(
      id: const Uuid().v4(),
      roomName: name,
      sessionKey: const Uuid().v4().replaceAll('-', ''),
      memberPeerIds: [],
      createdAt: DateTime.now(),
    );
  }

  BitmeshGroupRoom rotateKey() {
    return BitmeshGroupRoom(
      id: id,
      roomName: roomName,
      sessionKey: const Uuid().v4().replaceAll('-', ''),
      memberPeerIds: memberPeerIds,
      createdAt: DateTime.now(),
    );
  }
}
