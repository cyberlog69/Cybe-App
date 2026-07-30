import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../services/carrier_service.dart';
import '../services/speed_test_service.dart';

class NetworkDashboardScreen extends StatefulWidget {
  const NetworkDashboardScreen({super.key});
  @override
  State<NetworkDashboardScreen> createState() => _NetworkDashboardScreenState();
}

class _NetworkDashboardScreenState extends State<NetworkDashboardScreen> {
  final _networkInfo = NetworkInfo();
  final _connectivity = Connectivity();
  String _ssid = 'Unknown';
  String _ip = 'Unknown';
  String _gateway = 'Unknown';
  bool _isConnected = false;
  bool _hasInternet = false;
  String _connectionType = 'Unknown';

  // Mobile Data / Carrier Info
  CarrierDetails _carrierInfo = CarrierDetails.empty();
  bool _loadingCarrier = true;

  // Speed Test State
  bool _isSpeedTesting = false;
  SpeedTestProgress? _speedProgress;
  SpeedTestResult? _lastTestResult;
  StreamSubscription<SpeedTestProgress>? _speedTestSub;

  // Latency Chart
  final List<FlSpot> _latencySpots = [];
  double _latency = 0;
  int _spotIndex = 0;
  Timer? _pingTimer;

  // DNS Lookup
  final _dnsController = TextEditingController();
  String _dnsResult = '';

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
    _loadCarrierInfo();
    _startPingMonitor();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _speedTestSub?.cancel();
    _dnsController.dispose();
    super.dispose();
  }

  Future<void> _loadNetworkInfo() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      final ip = await _networkInfo.getWifiIP();
      final gateway = await _networkInfo.getWifiGatewayIP();
      final result = await _connectivity.checkConnectivity();
      final hasInternet = await InternetConnection().hasInternetAccess;
      setState(() {
        _ssid = ssid?.replaceAll('"', '') ?? 'Not connected';
        _ip = ip ?? 'N/A';
        _gateway = gateway ?? 'N/A';
        _isConnected = !result.contains(ConnectivityResult.none);
        _hasInternet = hasInternet;
        _connectionType = result.contains(ConnectivityResult.wifi)
            ? 'Wi-Fi'
            : result.contains(ConnectivityResult.mobile)
                ? 'Mobile Data'
                : 'None';
      });
    } catch (e) {
      debugPrint('Network info error: $e');
    }
  }

  Future<void> _loadCarrierInfo() async {
    setState(() => _loadingCarrier = true);
    final details = await CarrierService.getCarrierInfo();
    if (mounted) {
      setState(() {
        _carrierInfo = details;
        _loadingCarrier = false;
      });
    }
  }

  void _startPingMonitor() {
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final sw = Stopwatch()..start();
      final hasInternet = await InternetConnection().hasInternetAccess;
      sw.stop();
      final ms = hasInternet ? sw.elapsedMilliseconds.toDouble() : 999.0;
      if (mounted) {
        setState(() {
          _latency = ms;
          _spotIndex++;
          _latencySpots.add(FlSpot(_spotIndex.toDouble(), ms.clamp(0, 500).toDouble()));
          if (_latencySpots.length > 20) _latencySpots.removeAt(0);
        });
      }
    });
  }

  void _startSpeedTest() {
    if (_isSpeedTesting) return;
    setState(() {
      _isSpeedTesting = true;
      _speedProgress = null;
    });

    _speedTestSub?.cancel();
    _speedTestSub = SpeedTestService.runSpeedTest().listen(
      (progress) {
        if (mounted) {
          setState(() {
            _speedProgress = progress;
            if (progress.phase == 'Speed Test Complete') {
              _isSpeedTesting = false;
              _lastTestResult = SpeedTestResult(
                downloadMbps: progress.downloadMbps,
                uploadMbps: progress.uploadMbps,
                latencyMs: progress.latencyMs,
                jitterMs: progress.jitterMs,
                testedAt: DateTime.now(),
              );
            }
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isSpeedTesting = false;
            _speedProgress = SpeedTestProgress(
              phase: 'Error',
              progress: 0.0,
              errorMessage: err.toString(),
            );
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Dashboard'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadNetworkInfo();
              _loadCarrierInfo();
            },
            tooltip: 'Refresh Network Info',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildConnectionCard(),
              const SizedBox(height: 14),
              _buildCarrierCard(),
              const SizedBox(height: 14),
              _buildSpeedTestCard(),
              const SizedBox(height: 14),
              _buildLatencyChart(),
              const SizedBox(height: 14),
              _buildInfoCard(),
              const SizedBox(height: 14),
              _buildDnsLookup(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? AppTheme.safe : AppTheme.danger,
                  boxShadow: [
                    BoxShadow(
                      color: (_isConnected ? AppTheme.safe : AppTheme.danger)
                          .withValues(alpha: 0.6),
                      blurRadius: 8,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isConnected ? 'Connected — $_connectionType' : 'Disconnected',
                style: TextStyle(
                  color: _isConnected ? AppTheme.safe : AppTheme.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_hasInternet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.safe.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Internet OK',
                      style: TextStyle(
                          color: AppTheme.safe,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Connection Type', _connectionType),
          _infoRow('SSID / Access Point', _ssid),
          _infoRow('IP Address', _ip),
          _infoRow('Gateway IP', _gateway),
          _infoRow('Real-time Latency', '${_latency.toInt()} ms'),
        ],
      ),
    );
  }

  Widget _buildCarrierCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sim_card_outlined, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Text('Cellular & SIM Carrier Info',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const Spacer(),
              if (_carrierInfo.isMultiSimSupported)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Multi-SIM',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _carrierInfo.activeSlotCount > 1
                      ? '${_carrierInfo.activeSlotCount} SIMs'
                      : _carrierInfo.activeSlotCount == 1
                          ? '1 SIM'
                          : 'No SIM',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingCarrier)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            )
          else if (_carrierInfo.simSlots.isEmpty)
            _infoRow('Status', 'No cellular connectivity or SIM detected')
          else ...[
            for (int i = 0; i < _carrierInfo.simSlots.length; i++) ...[
              if (i > 0) const Divider(height: 20, color: AppTheme.surfaceVariant),
              _simSlotHeader(_carrierInfo.simSlots[i]),
              const SizedBox(height: 8),
              _infoRow('Carrier', _carrierInfo.simSlots[i].carrierName),
              _infoRow('SIM Type', _carrierInfo.simSlots[i].simType),
              if (_carrierInfo.simSlots[i].networkGeneration.isNotEmpty &&
                  _carrierInfo.simSlots[i].networkGeneration != 'Unknown')
                _infoRow('Network Gen', _carrierInfo.simSlots[i].networkGeneration),
              if (_carrierInfo.simSlots[i].radioType != 'Unknown')
                _infoRow('Radio Type', _carrierInfo.simSlots[i].radioType),
              _infoRow('Country (ISO)', _carrierInfo.simSlots[i].isoCountryCode),
              _infoRow('MCC / MNC',
                  '${_carrierInfo.simSlots[i].mobileCountryCode} / ${_carrierInfo.simSlots[i].mobileNetworkCode}'),
              if (_carrierInfo.simSlots[i].phoneNumber != 'Not Provisioned')
                _infoRow('Phone Number', _carrierInfo.simSlots[i].phoneNumber),
              if (_carrierInfo.simSlots[i].isRoaming)
                _infoRow('Roaming', 'Active'),
              if (_carrierInfo.simSlots[i].simState != 'Unknown')
                _infoRow('SIM State', _carrierInfo.simSlots[i].simState),
            ],
            const Divider(height: 20, color: AppTheme.surfaceVariant),
            _infoRow('IMEI Status', _carrierInfo.imeiStatus),
            if (_carrierInfo.supportsEmbeddedSim)
              _infoRow('eSIM Support', 'Available'),
          ],
        ],
      ),
    );
  }

  Widget _simSlotHeader(SimCardInfo sim) {
    return Row(
      children: [
        Icon(
          sim.isEmbedded ? Icons.sim_card_download_outlined : Icons.sim_card_outlined,
          size: 18,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 8),
        Text(sim.simSlotLabel,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const Spacer(),
        if (sim.networkGeneration.isNotEmpty && sim.networkGeneration != 'Unknown')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(sim.networkGeneration,
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildSpeedTestCard() {
    final prog = _speedProgress;
    final res = _lastTestResult;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.05),
            blurRadius: 16,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppTheme.secondary, size: 24),
              const SizedBox(width: 10),
              const Text('Network Speed Test',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSpeedTesting ? null : _startSpeedTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: _isSpeedTesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_isSpeedTesting ? 'Testing...' : 'Start Test'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Speed Test Progress / Gauges
          if (_isSpeedTesting && prog != null) ...[
            Text(prog.phase,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: prog.progress,
              backgroundColor: AppTheme.surfaceVariant,
              color: AppTheme.primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _speedMetricCard(
                    'DOWNLOAD',
                    '${prog.downloadMbps.toStringAsFixed(1)} Mbps',
                    Icons.download_rounded,
                    AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _speedMetricCard(
                    'UPLOAD',
                    '${prog.uploadMbps.toStringAsFixed(1)} Mbps',
                    Icons.upload_rounded,
                    AppTheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _speedMetricCard(
                    'PING',
                    '${prog.latencyMs.toInt()} ms',
                    Icons.timer_outlined,
                    AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _speedMetricCard(
                    'JITTER',
                    '${prog.jitterMs.toStringAsFixed(1)} ms',
                    Icons.equalizer_rounded,
                    AppTheme.accent,
                  ),
                ),
              ],
            ),
          ] else if (res != null) ...[
            Row(
              children: [
                Expanded(
                  child: _speedMetricCard(
                    'DOWNLOAD',
                    '${res.downloadMbps.toStringAsFixed(1)} Mbps',
                    Icons.download_rounded,
                    AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _speedMetricCard(
                    'UPLOAD',
                    '${res.uploadMbps.toStringAsFixed(1)} Mbps',
                    Icons.upload_rounded,
                    AppTheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _speedMetricCard(
                    'PING',
                    '${res.latencyMs.toInt()} ms',
                    Icons.timer_outlined,
                    AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _speedMetricCard(
                    'JITTER',
                    '${res.jitterMs.toStringAsFixed(1)} ms',
                    Icons.equalizer_rounded,
                    AppTheme.accent,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.speed, color: AppTheme.textSecondary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap "Start Test" to measure real-time download speed, upload speed, latency & jitter.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _speedMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLatencyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Continuous Latency Monitor (ms)',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _latencySpots.length < 2
                ? const Center(
                    child: Text('Collecting latency data...',
                        style: TextStyle(color: AppTheme.textSecondary)))
                : LineChart(LineChartData(
                    gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: AppTheme.divider, strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(
                                  v.toInt().toString(),
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10)))),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _latencySpots,
                        isCurved: true,
                        color: AppTheme.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connection Details',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _infoRow('Status', _isConnected ? 'Active' : 'Inactive'),
          _infoRow('Internet Access', _hasInternet ? 'Available' : 'Not available'),
          _infoRow('Connection Type', _connectionType),
          _infoRow('Local IP', _ip),
          _infoRow('Default Gateway', _gateway),
        ],
      ),
    );
  }

  Widget _buildDnsLookup() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DNS Lookup Tool',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dnsController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                      hintText: 'Enter hostname...',
                      prefixIcon: Icon(Icons.dns_outlined)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _dnsLookup,
                child: const Text('Lookup'),
              ),
            ],
          ),
          if (_dnsResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_dnsResult,
                style: const TextStyle(
                    color: AppTheme.primary, fontFamily: 'monospace')),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _dnsLookup() async {
    final host = _dnsController.text.trim();
    if (host.isEmpty) return;
    try {
      final addresses = await InternetAddress.lookup(host);
      setState(() {
        _dnsResult = addresses.map((a) => a.address).join('\n');
      });
    } catch (e) {
      setState(() => _dnsResult = 'Lookup failed: $e');
    }
  }
}
