/// Represents a single encrypted file entry in the Cybe File Vault.
/// Uses a plain Dart class with toMap/fromMap for Hive storage (no code generation required).
class VaultFileEntry {
  final String id;
  final String name;
  final String encryptedPath;
  final String originalExtension;
  final int sizeBytes;
  final DateTime encryptedAt;

  const VaultFileEntry({
    required this.id,
    required this.name,
    required this.encryptedPath,
    required this.originalExtension,
    required this.sizeBytes,
    required this.encryptedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'encryptedPath': encryptedPath,
    'originalExtension': originalExtension,
    'sizeBytes': sizeBytes,
    'encryptedAt': encryptedAt.toIso8601String(),
  };

  factory VaultFileEntry.fromMap(Map<dynamic, dynamic> map) => VaultFileEntry(
    id: map['id'] as String,
    name: map['name'] as String,
    encryptedPath: map['encryptedPath'] as String,
    originalExtension: map['originalExtension'] as String,
    sizeBytes: (map['sizeBytes'] as num).toInt(),
    encryptedAt: DateTime.parse(map['encryptedAt'] as String),
  );
}
