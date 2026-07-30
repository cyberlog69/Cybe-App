import 'dart:typed_data';

class AppPermissionInfo {
  final String appName;
  final String packageName;
  final String versionName;
  final bool isSystemApp;
  final List<String> permissions;
  final Uint8List? iconBytes;
  final int riskScore; // 0 to 100
  final String riskLevel; // 'High Risk', 'Medium Risk', 'Safe'

  const AppPermissionInfo({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.isSystemApp,
    required this.permissions,
    this.iconBytes,
    required this.riskScore,
    required this.riskLevel,
  });

  bool get hasCameraPermission =>
      permissions.any((p) => p.contains('CAMERA'));

  bool get hasMicrophonePermission =>
      permissions.any((p) => p.contains('RECORD_AUDIO'));

  bool get hasLocationPermission =>
      permissions.any((p) => p.contains('LOCATION'));

  bool get hasSmsPermission =>
      permissions.any((p) => p.contains('SMS'));

  bool get hasContactsPermission =>
      permissions.any((p) => p.contains('CONTACTS'));

  bool get hasPhoneStatePermission =>
      permissions.any((p) => p.contains('PHONE_STATE') || p.contains('CALL_LOG'));

  bool get hasStoragePermission =>
      permissions.any((p) => p.contains('STORAGE') || p.contains('READ_MEDIA'));

  List<String> get privacyThreats {
    final threats = <String>[];
    if (hasCameraPermission) threats.add('Camera Access');
    if (hasMicrophonePermission) threats.add('Microphone Access');
    if (hasLocationPermission) threats.add('GPS Location');
    if (hasSmsPermission) threats.add('SMS Messages');
    if (hasContactsPermission) threats.add('Contacts List');
    if (hasPhoneStatePermission) threats.add('Phone & Calls');
    if (hasStoragePermission) threats.add('Files & Media');
    return threats;
  }
}
