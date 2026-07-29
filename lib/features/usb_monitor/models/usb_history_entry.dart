// Data models for USB Monitor. No code-generation required;
// serialised manually as Hive Maps.


/// Describes a single connected USB device with its trust status.
class UsbDeviceInfo {
  final String vendorId;
  final String productId;
  final String? manufacturer;
  final String? productName;
  final DateTime connectedAt;
  final bool isTrusted;

  const UsbDeviceInfo({
    required this.vendorId,
    required this.productId,
    this.manufacturer,
    this.productName,
    required this.connectedAt,
    this.isTrusted = false,
  });

  String get displayName =>
      productName ?? manufacturer ?? 'Unknown USB Device';

  /// Unique key used to identify / match this device across scans.
  String get deviceKey => '${vendorId}_$productId';

  UsbDeviceInfo copyWith({bool? isTrusted}) => UsbDeviceInfo(
        vendorId: vendorId,
        productId: productId,
        manufacturer: manufacturer,
        productName: productName,
        connectedAt: connectedAt,
        isTrusted: isTrusted ?? this.isTrusted,
      );
}

/// A persisted USB event (connected / disconnected / trusted / blocked).
class UsbHistoryEntry {
  final String id;
  final String deviceName;
  final String vendorId;
  final String productId;

  /// One of: 'connected', 'disconnected', 'trusted', 'blocked'
  final String eventType;
  final DateTime timestamp;

  const UsbHistoryEntry({
    required this.id,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.eventType,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'deviceName': deviceName,
        'vendorId': vendorId,
        'productId': productId,
        'eventType': eventType,
        'timestamp': timestamp.toIso8601String(),
      };

  factory UsbHistoryEntry.fromMap(Map<dynamic, dynamic> map) =>
      UsbHistoryEntry(
        id: map['id'] as String,
        deviceName: map['deviceName'] as String,
        vendorId: map['vendorId'] as String,
        productId: map['productId'] as String,
        eventType: map['eventType'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
