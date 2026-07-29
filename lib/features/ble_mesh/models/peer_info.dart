class MeshPeerInfo {
  final String deviceId;
  final String name;
  final int rssi;

  const MeshPeerInfo({
    required this.deviceId,
    required this.name,
    required this.rssi,
  });

  String get signalLabel {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -75) return 'Good';
    if (rssi >= -90) return 'Weak';
    return 'Very Weak';
  }
}
