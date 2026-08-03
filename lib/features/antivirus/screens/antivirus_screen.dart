import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/antivirus_threat.dart';
import '../services/antivirus_scanner_service.dart';
import '../services/quarantine_service.dart';

class AntivirusScreen extends StatefulWidget {
  const AntivirusScreen({super.key});

  @override
  State<AntivirusScreen> createState() => _AntivirusScreenState();
}

class _AntivirusScreenState extends State<AntivirusScreen>
    with SingleTickerProviderStateMixin {
  ScanMode _selectedMode = ScanMode.quick;
  bool _isScanning = false;
  ScanProgress? _progress;
  final List<AntivirusThreat> _detectedThreats = [];
  List<AntivirusThreat> _quarantinedList = [];
  StreamSubscription<ScanProgress>? _scanSub;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _loadQuarantined();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadQuarantined() async {
    final list = await QuarantineService.loadQuarantinedThreats();
    if (mounted) setState(() => _quarantinedList = list);
  }

  void _startScan({Directory? customDir, File? singleFile}) {
    _scanSub?.cancel();
    setState(() {
      _isScanning = true;
      _detectedThreats.clear();
      _progress = const ScanProgress(
        filesScanned: 0,
        threatsFound: 0,
        currentFile: 'Initializing scanner...',
        progressPercent: 0.0,
        isCompleted: false,
      );
    });

    _radarController.repeat();

    _scanSub = AntivirusScannerService.scanTarget(
      mode: _selectedMode,
      customDir: customDir,
      singleFile: singleFile,
      threatsFoundList: _detectedThreats,
    ).listen((progress) {
      if (mounted) {
        setState(() => _progress = progress);
        if (progress.isCompleted) {
          _radarController.stop();
          setState(() => _isScanning = false);
          if (_detectedThreats.isNotEmpty) {
            _showThreatRemediationModal();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Antivirus Scan Completed: No malware threats found!'),
                backgroundColor: AppTheme.safe,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _pickCustomFileOrFolder() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any);
      if (res != null && res.files.single.path != null) {
        final file = File(res.files.single.path!);
        _startScan(singleFile: file);
      }
    } catch (_) {}
  }

  void _showThreatRemediationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Malware Threats Flagged (${_detectedThreats.length})',
                  style: const TextStyle(
                      color: AppTheme.danger, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _detectedThreats.length,
                itemBuilder: (context, index) {
                  final threat = _detectedThreats[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bug_report_outlined, color: AppTheme.danger),
                      title: Text(threat.threatName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Category: ${threat.threatCategory}\nFile: ${threat.filePath}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shield, color: AppTheme.safe),
                            tooltip: 'Quarantine File',
                            onPressed: () async {
                              await QuarantineService.quarantineThreat(threat);
                              await _loadQuarantined();
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Quarantined "${threat.fileName}".'),
                                    backgroundColor: AppTheme.safe,
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: AppTheme.danger),
                            tooltip: 'Permanently Delete',
                            onPressed: () async {
                              await QuarantineService.deleteThreat(threat);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Deleted "${threat.fileName}".'),
                                    backgroundColor: AppTheme.safe,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      for (final threat in List<AntivirusThreat>.from(_detectedThreats)) {
                        await QuarantineService.quarantineThreat(threat);
                      }
                      await _loadQuarantined();
                      if (!mounted) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All flagged threats quarantined safely.'),
                          backgroundColor: AppTheme.safe,
                        ),
                      );
                    },
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('Quarantine All Threats'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cross-Platform Antivirus Engine'),
          backgroundColor: AppTheme.background,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.security_rounded), text: 'Malware Scanner'),
              Tab(icon: Icon(Icons.folder_special_rounded), text: 'Quarantine Vault'),
            ],
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: TabBarView(
            children: [
              _buildScannerTab(),
              _buildQuarantineTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerTab() {
    return ResponsiveCenter(
      maxWidth: 950,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Platform Security Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cybe Multi-Engine Antivirus Active on ${Platform.operatingSystem.toUpperCase()}: Hash Signatures, Pattern Heuristics, and Obfuscation Detection active.',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Radar Scanner Card
          _buildRadarScannerCard(),
          const SizedBox(height: 16),

          // Scan Mode Selectors
          const Text('Select Antivirus Scan Profile:',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _scanModeCard(ScanMode.quick, 'Quick Scan', 'Downloads & Temp', Icons.bolt_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _scanModeCard(ScanMode.full, 'Full Scan', 'Deep System Pass', Icons.saved_search_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _pickCustomFileOrFolder,
            icon: const Icon(Icons.file_open_outlined, size: 18),
            label: const Text('Scan Custom File / Folder'),
          ),
          const SizedBox(height: 20),

          // Detected Threats Summary Card
          if (_detectedThreats.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_detectedThreats.length} Threats Detected!',
                            style: const TextStyle(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const Text('Review flagged files and isolate them in Quarantine Vault.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showThreatRemediationModal,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                    child: const Text('Review Threats'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadarScannerCard() {
    final isDone = _progress?.isCompleted ?? false;
    final threats = _progress?.threatsFound ?? 0;
    final statusColor = threats > 0 ? AppTheme.danger : AppTheme.safe;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _isScanning
                ? AppTheme.primary.withValues(alpha: 0.5)
                : statusColor.withValues(alpha: 0.3),
            width: 1.5),
      ),
      child: Column(
        children: [
          RotationTransition(
            turns: _radarController,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_isScanning ? AppTheme.primary : statusColor).withValues(alpha: 0.15),
                border: Border.all(color: _isScanning ? AppTheme.primary : statusColor, width: 2),
              ),
              child: Icon(
                _isScanning
                    ? Icons.radar_rounded
                    : threats > 0
                        ? Icons.bug_report_rounded
                        : Icons.verified_user_rounded,
                color: _isScanning ? AppTheme.primary : statusColor,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning
                ? 'SCANNING SYSTEM FILES...'
                : isDone
                    ? (threats > 0 ? 'MALWARE THREATS DETECTED' : 'SYSTEM PROTECTED & CLEAN')
                    : 'ANTIVIRUS READY',
            style: TextStyle(
              color: _isScanning ? AppTheme.primary : statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 17,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _progress?.currentFile ?? 'Tap Quick or Full Scan to start analysis',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress?.progressPercent ?? 0.0,
            backgroundColor: AppTheme.surfaceVariant,
            color: _isScanning ? AppTheme.primary : statusColor,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Files Scanned: ${_progress?.filesScanned ?? 0}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text('Threats Found: $threats',
                  style: TextStyle(
                      color: threats > 0 ? AppTheme.danger : AppTheme.safe,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : () => _startScan(),
            icon: Icon(_isScanning ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded),
            label: Text(_isScanning ? 'Scanning...' : 'Start Antivirus Scan'),
          ),
        ],
      ),
    );
  }

  Widget _scanModeCard(ScanMode mode, String title, String subtitle, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFF1E1E30),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 24),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(subtitle,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarantineTab() {
    return ResponsiveCenter(
      maxWidth: 950,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.folder_special_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                'Quarantine Vault (${_quarantinedList.length})',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Isolated malicious files encrypted and prevented from executing.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          if (_quarantinedList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Quarantine Vault is empty.\nNo isolated malware threats.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                ),
              ),
            )
          else
            ..._quarantinedList.map((threat) => _buildQuarantineItemCard(threat)),
        ],
      ),
    );
  }

  Widget _buildQuarantineItemCard(AntivirusThreat threat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shield_outlined, color: AppTheme.danger),
        ),
        title: Text(threat.fileName,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Threat: ${threat.threatName}\nOriginal Path: ${threat.filePath}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.undo_rounded, color: AppTheme.primary),
              tooltip: 'Restore File',
              onPressed: () async {
                await QuarantineService.restoreThreat(threat);
                await _loadQuarantined();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppTheme.danger),
              tooltip: 'Permanently Destroy',
              onPressed: () async {
                await QuarantineService.deleteThreat(threat);
                await _loadQuarantined();
              },
            ),
          ],
        ),
      ),
    );
  }
}
