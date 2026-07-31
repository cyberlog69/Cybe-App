import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/qr_scan_result.dart';
import '../services/qr_inspector_service.dart';

class QrInspectorScreen extends StatefulWidget {
  const QrInspectorScreen({super.key});

  @override
  State<QrInspectorScreen> createState() => _QrInspectorScreenState();
}

class _QrInspectorScreenState extends State<QrInspectorScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  bool _isAnalyzing = false;
  bool _isTorchOn = false;
  late AnimationController _reticleController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _reticleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _reticleController.dispose();
    super.dispose();
  }

  Future<void> _processBarcodePayload(String raw) async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);

    final result = await QrInspectorService.analyzePayload(raw);
    if (mounted) {
      _showSecurityAnalysisModal(result);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res != null && res.files.single.path != null) {
        final path = res.files.single.path!;
        final capture = await _scannerController.analyzeImage(path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final raw = capture.barcodes.first.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _processBarcodePayload(raw);
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code detected in selected image.'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[QrInspectorScreen] Gallery pick error: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Malicious QR Security Inspector'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _isTorchOn ? AppTheme.warning : AppTheme.textSecondary),
            tooltip: 'Toggle Flashlight',
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: 'Flip Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: Column(
            children: [
              // Scanner Viewport
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              final raw = barcodes.first.rawValue;
                              if (raw != null && raw.isNotEmpty) {
                                _processBarcodePayload(raw);
                              }
                            }
                          },
                        ),

                        // Cyber Reticle Overlay
                        AnimatedBuilder(
                          animation: _reticleController,
                          builder: (ctx, child) {
                            return Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(
                                      alpha: 0.4 + (_reticleController.value * 0.6)),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(
                                        alpha: 0.2 * _reticleController.value),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const Positioned(
                          bottom: 20,
                          child: Text(
                            'Align QR Code Inside Camera Viewport',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImageFromGallery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceVariant,
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 20),
                        label: const Text('Import QR Image from Gallery'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecurityAnalysisModal(QrScanResult result) {
    Color levelColor = AppTheme.safe;
    if (result.safetyLevel == QrSafetyLevel.suspicious) levelColor = AppTheme.warning;
    if (result.safetyLevel == QrSafetyLevel.malicious) levelColor = AppTheme.danger;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      result.safetyLevel == QrSafetyLevel.malicious
                          ? Icons.gpp_bad_rounded
                          : result.safetyLevel == QrSafetyLevel.suspicious
                              ? Icons.gpp_maybe_rounded
                              : Icons.gpp_good_rounded,
                      color: levelColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.safetyLevel.name.toUpperCase()} QR PAYLOAD',
                          style: TextStyle(
                              color: levelColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text(
                          'Threat Score: ${result.threatScore} / 100',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _isAnalyzing = false);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Raw & Unmasked Payload Box
              const Text('Scanned Content / Target URL:',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: levelColor.withValues(alpha: 0.3)),
                ),
                child: SelectableText(
                  result.unmaskedUrl.isNotEmpty ? result.unmaskedUrl : result.rawPayload,
                  style: TextStyle(
                      color: levelColor,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 14),

              // Threat Badges
              if (result.threatBadges.isNotEmpty) ...[
                const Text('Security Threats Identified:',
                    style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 6),
                ...result.threatBadges.map((badge) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(badge.title,
                              style: const TextStyle(
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(badge.description,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 11)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],

              // Recommendations
              const Text('Security Recommendation:',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...result.recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(rec,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 12))),
                      ],
                    ),
                  )),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: result.unmaskedUrl.isNotEmpty
                                ? result.unmaskedUrl
                                : result.rawPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied payload to clipboard.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Link'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (result.payloadType == QrPayloadType.url)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(result.unmaskedUrl.isNotEmpty
                              ? result.unmaskedUrl
                              : result.rawPayload);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: levelColor,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                        label: const Text('Open URL'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() => _isAnalyzing = false);
    });
  }
}
