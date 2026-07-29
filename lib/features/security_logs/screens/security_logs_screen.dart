import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';

class SecurityEvent {
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'critical'
  final DateTime timestamp;

  const SecurityEvent({
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
  });
}

class SecurityLogsScreen extends StatelessWidget {
  const SecurityLogsScreen({super.key});

  static final List<SecurityEvent> _mockEvents = [
    SecurityEvent(title: 'App Lock Engaged', message: 'Biometric lock challenge passed', severity: 'info', timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
    SecurityEvent(title: 'USB Monitor Active', message: 'USB interface connected & scanned', severity: 'info', timestamp: DateTime.now().subtract(const Duration(minutes: 12))),
    SecurityEvent(title: 'Wi-Fi Threat Scan', message: 'Wi-Fi security analysis completed', severity: 'info', timestamp: DateTime.now().subtract(const Duration(hours: 1))),
    SecurityEvent(title: 'Dark Web Audit', message: 'Password leak lookup performed', severity: 'warning', timestamp: DateTime.now().subtract(const Duration(hours: 3))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Event Log'),
        backgroundColor: AppTheme.background,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _mockEvents.length,
            itemBuilder: (ctx, i) {
              final event = _mockEvents[i];
              final color = event.severity == 'critical' ? AppTheme.danger : event.severity == 'warning' ? AppTheme.warning : AppTheme.safe;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(event.severity == 'critical' ? Icons.error_outline : event.severity == 'warning' ? Icons.warning_amber_rounded : Icons.info_outline, color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(event.message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(DateFormat('HH:mm').format(event.timestamp), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
