import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../services/clipboard_service.dart';

class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({super.key});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  Future<void> _fetchSystemClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        ClipboardService.addClip(data.text!);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSystemClipboard();
  }

  @override
  Widget build(BuildContext context) {
    final clips = ClipboardService.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure In-App Clipboard'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: () {
              setState(() {
                ClipboardService.clearHistory();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSystemClipboard,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: AppTheme.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Ephemeral Clipboard Storage: Automatically wiped on app lock.', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (clips.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E1E30))),
                  child: const Column(
                    children: [
                      Icon(Icons.content_paste_off, color: AppTheme.textSecondary, size: 48),
                      SizedBox(height: 12),
                      Text('Clipboard History Empty', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                ...clips.map((clip) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E1E30))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(clip, style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace', fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: AppTheme.primary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: clip));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                        },
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
