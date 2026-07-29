import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';

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
  final List<FlSpot> _latencySpots = [];
  double _latency = 0;
  int _spotIndex = 0;
  Timer? _pingTimer;
  final _dnsController = TextEditingController();
  String _dnsResult = '';

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
    _startPingMonitor();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
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
        _connectionType = result.contains(ConnectivityResult.wifi) ? 'Wi-Fi'
            : result.contains(ConnectivityResult.mobile) ? 'Mobile Data'
            : 'None';
      });
    } catch (e) {
      debugPrint('Network info error: $e');
    }
  }

  void _startPingMonitor() {
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final sw = Stopwatch()..start();
      final hasInternet = await InternetConnection().hasInternetAccess;
      sw.stop();
      final ms = hasInternet ? sw.elapsedMilliseconds.toDouble() : 999.0;
      setState(() {
        _latency = ms;
        _spotIndex++;
        _latencySpots.add(FlSpot(_spotIndex.toDouble(), ms.clamp(0, 500).toDouble()));
        if (_latencySpots.length > 20) _latencySpots.removeAt(0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Dashboard'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNetworkInfo, tooltip: 'Refresh'),
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
              const SizedBox(height: 12),
              _buildLatencyChart(),
              const SizedBox(height: 12),
              _buildInfoCard(),
              const SizedBox(height: 12),
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
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? AppTheme.safe : AppTheme.danger,
                  boxShadow: [BoxShadow(color: (_isConnected ? AppTheme.safe : AppTheme.danger).withValues(alpha: 0.6), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 10),
              Text(_isConnected ? 'Connected — $_connectionType' : 'Disconnected',
                style: TextStyle(color: _isConnected ? AppTheme.safe : AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_hasInternet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.safe.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Internet OK', style: TextStyle(color: AppTheme.safe, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('SSID', _ssid),
          _infoRow('IP Address', _ip),
          _infoRow('Gateway', _gateway),
          _infoRow('Latency', '${_latency.toInt()} ms'),
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
          const Text('Latency Monitor (ms)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _latencySpots.length < 2
                ? const Center(child: Text('Collecting data...', style: TextStyle(color: AppTheme.textSecondary)))
                : LineChart(LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.divider, strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)))),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          const Text('Connection Details', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
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
          const Text('DNS Lookup Tool', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dnsController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Enter hostname...', prefixIcon: Icon(Icons.dns_outlined)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _dnsLookup,
                child: const Text('Lookup'),
              ),
            ],
          ),
          if (_dnsResult.isNotEmpty) ...[const SizedBox(height: 12), Text(_dnsResult, style: const TextStyle(color: AppTheme.primary, fontFamily: 'monospace'))],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
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
