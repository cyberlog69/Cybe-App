class DetectedIpCam {
  final String ip;
  final String mac;
  final int port;
  final String deviceType;

  const DetectedIpCam({
    required this.ip,
    required this.mac,
    required this.port,
    required this.deviceType,
  });
}

class SpywareScanReport {
  final double currentMicroTesla; // Ambient magnetic field (uT)
  final String emfRiskLevel; // 'SAFE', 'ELEVATED', 'SUSPECTED BUG DETECTED'
  final List<DetectedIpCam> detectedCams;
  final int totalDevicesScanned;
  final DateTime lastScanTime;

  const SpywareScanReport({
    required this.currentMicroTesla,
    required this.emfRiskLevel,
    required this.detectedCams,
    required this.totalDevicesScanned,
    required this.lastScanTime,
  });
}
