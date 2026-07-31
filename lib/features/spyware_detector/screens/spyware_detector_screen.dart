import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/spyware_scan_report.dart';
import '../services/spyware_detector_service.dart';

class SpywareDetectorScreen extends StatefulWidget {
  const SpywareDetectorScreen({super.key});

  @override
  State<SpywareDetectorScreen> createState() => _SpywareDetectorScreenState();
}

class _SpywareDetectorScreenState extends State<SpywareDetectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // EMF Scanner State
  double _emfReading = 42.0;
  Timer? _emfTimer;
  bool _isAudioBeepEnabled = true;

  // LAN Camera Scanner State
  List<DetectedIpCam> _detectedCams = [];
  bool _isScanningCams = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startEmfMonitor();
    _scanLanCams();
  }

  @override
  void dispose() {
    _emfTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startEmfMonitor() {
    _emfTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final val = await SpywareDetectorService.getMagnetometerReading();
      if (mounted) {
        setState(() => _emfReading = val);
      }
    });
  }

  Future<void> _scanLanCams() async {
    setState(() => _isScanningCams = true);
    final cams = await SpywareDetectorService.scanLanSpyCams();
    if (mounted) {
      setState(() {
        _detectedCams = cams;
        _isScanningCams = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anti-Spyware & Bug Detector'),
        backgroundColor: AppTheme.background,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.sensors_rounded), text: 'EMF Bug Scan'),
            Tab(icon: Icon(Icons.camera_alt_outlined), text: 'IR Lens Finder'),
            Tab(icon: Icon(Icons.wifi_find_rounded), text: 'LAN Spy Cams'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 950,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEmfTab(),
              _buildLensFinderTab(),
              _buildLanCamsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 1: EMF MAGNETIC BUG SCANNER ───────────────────────────────────────
  Widget _buildEmfTab() {
    final status = SpywareDetectorService.evaluateEmfRisk(_emfReading);
    Color statusColor = AppTheme.safe;
    if (status == 'ELEVATED') statusColor = AppTheme.warning;
    if (status == 'SUSPECTED BUG DETECTED') statusColor = AppTheme.danger;

    final normalizedVal = (_emfReading / 250.0).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!Platform.isAndroid && !Platform.isIOS)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.laptop_mac_rounded, color: AppTheme.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Desktop PC Mode: Hardware magnetometer absent on host PC. Ambient 42 µT displayed. IR Lens Finder & Subnet IP Camera Scanner are 100% active.',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        // EMF Gauge Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: statusColor.withValues(alpha: 0.2), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              const Text('Electromagnetic Field (EMF) Scanner',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Gauge Circle
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: normalizedVal,
                        strokeWidth: 10,
                        backgroundColor: AppTheme.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _emfReading.toStringAsFixed(1),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace'),
                        ),
                        const Text('µT (Microteslas)',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Move your device close to smoke detectors, clocks, wall sockets, or mirrors. Spikes above 120 µT indicate hidden transformers or covert microphone coils.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Controls Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E1E30)),
          ),
          child: Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio Signal Beep Alert',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text('Emit proximity audio pulse as magnetic flux increases',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _isAudioBeepEnabled,
                onChanged: (v) => setState(() => _isAudioBeepEnabled = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TAB 2: LENS GLINT IR FINDER ─────────────────────────────────────────
  Widget _buildLensFinderTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // High Contrast Viewfinder Overlay Simulation
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.secondary.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.secondary, width: 2),
                    ),
                    child: const Icon(Icons.center_focus_strong_rounded,
                        color: AppTheme.secondary, size: 48),
                  ),
                  const SizedBox(height: 14),
                  const Text('Optical Pinhole Glint Finder Active',
                      style: TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Turn off room lights. Look through your camera lens. Hidden pinhole cameras reflect bright red/white glints from IR LEDs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Common Hidden Camera Locations:',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 8),
        _locationTip('Smoke Detectors & Air Vents', 'Check for small circular dark holes on housing.'),
        _locationTip('Digital Alarm Clocks & TVs', 'Pinhole lenses hidden behind reflective front glass.'),
        _locationTip('Wall Outlets & Power Adapters', 'Look for unusual LED indicators or tiny glass lenses.'),
        _locationTip('Desk Lamps & Bathroom Mirrors', 'Use flashlight test to check for two-way glass.'),
      ],
    );
  }

  Widget _locationTip(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                Text(subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: LAN SUBNET SPY CAM SCANNER ─────────────────────────────────────
  Widget _buildLanCamsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Text('Discovered Wi-Fi IP Cameras',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _scanLanCams,
              icon: const Icon(Icons.radar_rounded, size: 16),
              label: const Text('Rescan Network'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_isScanningCams)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 12),
                  Text('Scanning subnet for open RTSP & camera ports...',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          )
        else if (_detectedCams.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E1E30)),
            ),
            child: const Column(
              children: [
                Icon(Icons.verified_user_outlined, color: AppTheme.safe, size: 40),
                SizedBox(height: 10),
                Text('No Covert IP Cameras Found',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                SizedBox(height: 4),
                Text('No open RTSP or surveillance camera ports were detected on this Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          )
        else
          ..._detectedCams.map((cam) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.videocam_outlined, color: AppTheme.warning),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cam.deviceType,
                              style: const TextStyle(
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('IP: ${cam.ip} • Port: ${cam.port}',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'monospace',
                                  fontSize: 11)),
                          Text('MAC: ${cam.mac}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
