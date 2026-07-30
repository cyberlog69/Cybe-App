import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/app_permission_info.dart';
import '../services/app_audit_service.dart';

class AppAuditScreen extends StatefulWidget {
  const AppAuditScreen({super.key});

  @override
  State<AppAuditScreen> createState() => _AppAuditScreenState();
}

class _AppAuditScreenState extends State<AppAuditScreen> {
  List<AppPermissionInfo> _allApps = [];
  bool _isLoading = true;
  bool _includeSystemApps = false;
  String _selectedRiskFilter = 'All'; // 'All', 'High Risk', 'Medium Risk', 'Safe'
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _filterOptions = ['All', 'High Risk', 'Medium Risk', 'Safe'];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await AppAuditService.getInstalledApps(includeSystemApps: _includeSystemApps);
    if (mounted) {
      setState(() {
        _allApps = apps;
        _isLoading = false;
      });
    }
  }

  List<AppPermissionInfo> get _filteredApps {
    return _allApps.where((app) {
      final matchesFilter = _selectedRiskFilter == 'All' || app.riskLevel == _selectedRiskFilter;
      final matchesQuery = _searchQuery.isEmpty ||
          app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();
  }

  int get _highRiskCount => _allApps.where((a) => a.riskLevel == 'High Risk').length;
  int get _mediumRiskCount => _allApps.where((a) => a.riskLevel == 'Medium Risk').length;
  int get _safeCount => _allApps.where((a) => a.riskLevel == 'Safe').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Permission & Privacy Guard'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan Installed Apps',
            onPressed: _loadApps,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 950,
          child: Column(
            children: [
              // Header Summary Card
              _buildSummaryHeader(),

              // Search & Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search app name or package...',
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
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filterOptions.map((opt) {
                                final isSelected = _selectedRiskFilter == opt;
                                Color badgeColor = AppTheme.primary;
                                if (opt == 'High Risk') badgeColor = AppTheme.danger;
                                if (opt == 'Medium Risk') badgeColor = AppTheme.warning;
                                if (opt == 'Safe') badgeColor = AppTheme.safe;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(opt),
                                    selected: isSelected,
                                    selectedColor: badgeColor,
                                    backgroundColor: AppTheme.surfaceVariant,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.black : AppTheme.textPrimary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) => setState(() => _selectedRiskFilter = opt),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('System Apps',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Switch(
                              value: _includeSystemApps,
                              onChanged: (val) {
                                setState(() => _includeSystemApps = val);
                                _loadApps();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Apps List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primary),
                            SizedBox(height: 16),
                            Text('Scanning installed application permissions...',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    : _filteredApps.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_outlined, size: 48, color: AppTheme.textSecondary),
                                SizedBox(height: 12),
                                Text('No applications match your filter.',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredApps.length,
                            itemBuilder: (ctx, i) {
                              return _buildAppTile(_filteredApps[i]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryStat('Scanned Apps', '${_allApps.length}', AppTheme.primary, Icons.apps_rounded),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _summaryStat('High Risk', '$_highRiskCount', AppTheme.danger, Icons.warning_amber_rounded),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _summaryStat('Medium Risk', '$_mediumRiskCount', AppTheme.warning, Icons.info_outline_rounded),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _summaryStat('Safe Apps', '$_safeCount', AppTheme.safe, Icons.check_circle_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildAppTile(AppPermissionInfo app) {
    Color riskColor = AppTheme.safe;
    if (app.riskLevel == 'High Risk') riskColor = AppTheme.danger;
    if (app.riskLevel == 'Medium Risk') riskColor = AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => _showAppInspectionSheet(app),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: app.iconBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(app.iconBytes!, fit: BoxFit.cover),
                )
              : const Icon(Icons.android_rounded, color: AppTheme.primary, size: 26),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                app.appName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: riskColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${app.riskScore} PTS — ${app.riskLevel}',
                style: TextStyle(
                    color: riskColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${app.packageName} • v${app.versionName}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (app.hasCameraPermission) _threatBadge('Camera', Icons.camera_alt_outlined, AppTheme.danger),
                if (app.hasMicrophonePermission) _threatBadge('Mic', Icons.mic_none_outlined, AppTheme.danger),
                if (app.hasLocationPermission) _threatBadge('GPS', Icons.location_on_outlined, AppTheme.warning),
                if (app.hasSmsPermission) _threatBadge('SMS', Icons.sms_outlined, AppTheme.danger),
                if (app.hasContactsPermission) _threatBadge('Contacts', Icons.contacts_outlined, AppTheme.warning),
                if (app.hasPhoneStatePermission) _threatBadge('Phone', Icons.phone_outlined, AppTheme.warning),
                if (app.hasStoragePermission) _threatBadge('Storage', Icons.folder_outlined, AppTheme.primary),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _threatBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showAppInspectionSheet(AppPermissionInfo app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: app.iconBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(app.iconBytes!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.android_rounded, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.appName,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(app.packageName,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),

              // Danger Summary
              Row(
                children: [
                  const Text('Privacy Risk Score:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const Spacer(),
                  Text('${app.riskScore} / 100 (${app.riskLevel})',
                      style: TextStyle(
                          color: app.riskLevel == 'High Risk'
                              ? AppTheme.danger
                              : app.riskLevel == 'Medium Risk'
                                  ? AppTheme.warning
                                  : AppTheme.safe,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 14),

              // Open Settings Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    AppAuditService.openAppDetails(app.packageName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.settings_applications_rounded, size: 18),
                  label: const Text('Manage & Revoke Permissions in Settings'),
                ),
              ),

              const SizedBox(height: 16),
              Text('Requested Permissions (${app.permissions.length}):',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),

              Expanded(
                child: app.permissions.isEmpty
                    ? const Center(
                        child: Text('No special permissions requested.',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: app.permissions.length,
                        itemBuilder: (c, idx) {
                          final perm = app.permissions[idx];
                          final isDangerous = perm.contains('CAMERA') ||
                              perm.contains('RECORD_AUDIO') ||
                              perm.contains('LOCATION') ||
                              perm.contains('SMS') ||
                              perm.contains('CONTACTS') ||
                              perm.contains('PHONE_STATE');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDangerous
                                  ? AppTheme.danger.withValues(alpha: 0.1)
                                  : AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: isDangerous
                                      ? AppTheme.danger.withValues(alpha: 0.3)
                                      : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isDangerous
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: isDangerous ? AppTheme.danger : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    perm.replaceAll('android.permission.', ''),
                                    style: TextStyle(
                                      color: isDangerous
                                          ? AppTheme.danger
                                          : AppTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: isDangerous
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
