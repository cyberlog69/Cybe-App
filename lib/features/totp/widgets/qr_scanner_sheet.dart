import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../services/totp_service.dart';

class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({super.key});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Scan 2FA QR Code', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Align the QR code inside the frame', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (_scanned) return;
                  final barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final raw = barcode.rawValue;
                    if (raw != null && raw.startsWith('otpauth://')) {
                      final item = TotpService.parseOtpAuthUrl(raw);
                      if (item != null) {
                        _scanned = true;
                        Navigator.pop(context, item);
                        break;
                      }
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            label: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
