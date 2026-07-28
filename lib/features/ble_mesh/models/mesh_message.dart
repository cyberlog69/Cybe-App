import 'dart:convert';

class MeshMessage {
  final String id;
  final String senderAlias;
  final String channel;
  final String encryptedData; // base64-encoded AES-256-GCM ciphertext, or plaintext for public channel
  final DateTime timestamp;
  final int hops;
  final int ttl;
  final bool isOwn;
  final bool isRelayed;

  const MeshMessage({
    required this.id,
    required this.senderAlias,
    required this.channel,
    required this.encryptedData,
    required this.timestamp,
    this.hops = 0,
    this.ttl = 5,
    this.isOwn = false,
    this.isRelayed = false,
  });

  MeshMessage copyWith({
    String? id,
    String? senderAlias,
    String? channel,
    String? encryptedData,
    DateTime? timestamp,
    int? hops,
    int? ttl,
    bool? isOwn,
    bool? isRelayed,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      senderAlias: senderAlias ?? this.senderAlias,
      channel: channel ?? this.channel,
      encryptedData: encryptedData ?? this.encryptedData,
      timestamp: timestamp ?? this.timestamp,
      hops: hops ?? this.hops,
      ttl: ttl ?? this.ttl,
      isOwn: isOwn ?? this.isOwn,
      isRelayed: isRelayed ?? this.isRelayed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': senderAlias,
    'ch': channel,
    'data': encryptedData,
    'ts': timestamp.millisecondsSinceEpoch,
    'hops': hops,
    'ttl': ttl,
  };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
    id: json['id'] as String,
    senderAlias: json['from'] as String? ?? 'Unknown',
    channel: json['ch'] as String? ?? 'cybe-public',
    encryptedData: json['data'] as String? ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
    hops: json['hops'] as int? ?? 0,
    ttl: json['ttl'] as int? ?? 5,
    isRelayed: (json['hops'] as int? ?? 0) > 0,
  );

  /// Encode to BLE payload bytes (JSON → UTF8)
  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  /// Decode from BLE payload bytes
  static MeshMessage? fromBytes(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return MeshMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Create a relay copy with incremented hop count
  MeshMessage relayed() => copyWith(hops: hops + 1, isRelayed: true);

  bool get canRelay => hops < ttl;
}
