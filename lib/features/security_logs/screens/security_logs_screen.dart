import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/security_event_log.dart';
import '../services/security_log_service.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  List<SecurityEventLog> _logs = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedSeverity = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _categories = ['All', 'System', 'Vault', 'Auth', 'Network', 'USB', 'BLE'];
  final List<String> _severities = ['All', 'critical', 'warning', 'info', 'safe'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await SecurityLogService.loadLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSystemLogcat() async {
    setState(() => _isLoading = true);
    final logcatLogs = await SecurityLogService.fetchAndroidSystemLogcat();
    if (logcatLogs.isNotEmpty) {
      for (final log in logcatLogs) {
        await SecurityLogService.logEvent(
          title: log.title,
          message: log.message,
          severity: log.severity,
          category: log.category,
          rawDetails: log.rawDetails,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fetched ${logcatLogs.length} Android System logcat entries.'),
            backgroundColor: AppTheme.safe,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No system logcat entries found or non-Android platform.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
    await _loadLogs();
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Clear Security Logs?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to clear all recorded system security logs?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SecurityLogService.clearLogs();
      await _loadLogs();
    }
  }

  Future<void> _exportLogs() async {
    final text = await SecurityLogService.exportLogsFormatted();
    await Share.share(text, subject: 'Cybe Security System Event Logs');
  }

  List<SecurityEventLog> get _filteredLogs {
    return _logs.where((log) {
      final matchesCategory = _selectedCategory == 'All' || log.category == _selectedCategory;
      final matchesSeverity = _selectedSeverity == 'All' || log.severity == _selectedSeverity;
      final matchesQuery = _searchQuery.isEmpty ||
          log.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (log.rawDetails != null && log.rawDetails!.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesCategory && matchesSeverity && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Security Event Log'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.phonelink_setup_rounded),
            tooltip: 'Fetch Logcat System Events',
            onPressed: _fetchSystemLogcat,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export Logs',
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear History',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 950,
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search event logs, messages, or tags...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                backgroundColor: AppTheme.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : AppTheme.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                                onSelected: (_) => setState(() => _selectedCategory = cat),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          ..._severities.map((sev) {
                            final isSelected = _selectedSeverity == sev;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(sev.toUpperCase()),
                                selected: isSelected,
                                selectedColor: sev == 'critical'
                                    ? AppTheme.danger
                                    : sev == 'warning'
                                        ? AppTheme.warning
                                        : AppTheme.secondary,
                                backgroundColor: AppTheme.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 10,
                                ),
                                onSelected: (_) => setState(() => _selectedSeverity = sev),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Log List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : _filteredLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 48, color: AppTheme.textSecondary),
                                const SizedBox(height: 12),
                                const Text('No system security events found.',
                                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Events logged across Cybe security modules will appear here.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchSystemLogcat,
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Read System Logcat Logs'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredLogs.length,
                            itemBuilder: (ctx, i) {
                              final event = _filteredLogs[i];
                              return _buildLogTile(event);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogTile(SecurityEventLog event) {
    Color color;
    IconData icon;

    switch (event.severity) {
      case 'critical':
        color = AppTheme.danger;
        icon = Icons.error_outline_rounded;
        break;
      case 'warning':
        color = AppTheme.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case 'safe':
        color = AppTheme.safe;
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        color = AppTheme.primary;
        icon = Icons.info_outline_rounded;
    }

    final formattedTime = DateFormat('MMM dd, HH:mm:ss').format(event.timestamp);

    return InkWell(
      onTap: () => _showEventDetailsDialog(event),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.category,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedTime,
                    style: const TextStyle(color: Color(0xFF6E6E90), fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetailsDialog(SecurityEventLog event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('System Event Log Details',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow('Event Title', event.title),
              _detailRow('Category', event.category),
              _detailRow('Severity', event.severity.toUpperCase()),
              _detailRow('Timestamp', event.timestamp.toIso8601String()),
              const SizedBox(height: 12),
              const Text('Description:',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(
                event.message,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              if (event.rawDetails != null && event.rawDetails!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Raw Log Details:',
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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: SelectableText(
                    event.rawDetails!,
                    style: const TextStyle(
                        color: AppTheme.secondary,
                        fontFamily: 'monospace',
                        fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
