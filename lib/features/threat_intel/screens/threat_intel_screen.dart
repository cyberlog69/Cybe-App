import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/threat_cve_item.dart';
import '../services/threat_intel_service.dart';

class ThreatIntelScreen extends StatefulWidget {
  const ThreatIntelScreen({super.key});

  @override
  State<ThreatIntelScreen> createState() => _ThreatIntelScreenState();
}

class _ThreatIntelScreenState extends State<ThreatIntelScreen> {
  List<ThreatCveItem> _allAdvisories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedSeverity = 'All';

  @override
  void initState() {
    super.initState();
    _loadThreatFeed();
  }

  Future<void> _loadThreatFeed() async {
    setState(() => _isLoading = true);
    final list = await ThreatIntelService.fetchThreatAdvisories();
    if (mounted) {
      setState(() {
        _allAdvisories = list;
        _isLoading = false;
      });
    }
  }

  List<ThreatCveItem> get _filteredAdvisories {
    return _allAdvisories.where((item) {
      final matchesSearch = item.cveId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.vulnerabilityName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedSeverity == 'All') return matchesSearch;
      if (_selectedSeverity == 'Critical') return matchesSearch && item.severity == CveSeverity.critical;
      if (_selectedSeverity == 'High') return matchesSearch && item.severity == CveSeverity.high;
      if (_selectedSeverity == 'Medium') return matchesSearch && item.severity == CveSeverity.medium;
      return matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = _allAdvisories.where((e) => e.severity == CveSeverity.critical).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cyber Threat Intel & CVE Feed'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Threat Feed',
            onPressed: _loadThreatFeed,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 950,
          child: Column(
            children: [
              // Global Threat Header Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: AppTheme.danger.withValues(alpha: 0.15), blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GLOBAL THREAT LEVEL: ELEVATED',
                              style: TextStyle(
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_allAdvisories.length} Active Zero-Days • $criticalCount Critical Explosive CVEs',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar & Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search CVE ID, Vendor (Microsoft, Apple, Google)...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Critical', 'High', 'Medium'].map((chip) {
                          final isSel = _selectedSeverity == chip;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(chip),
                              selected: isSel,
                              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                              backgroundColor: AppTheme.surfaceVariant,
                              labelStyle: TextStyle(
                                color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: isSel ? AppTheme.primary : Colors.transparent,
                              ),
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedSeverity = chip);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Advisory List View
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : _filteredAdvisories.isEmpty
                        ? const Center(
                            child: Text('No threat advisories matching filter.',
                                style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filteredAdvisories.length,
                            itemBuilder: (context, index) {
                              final cve = _filteredAdvisories[index];
                              return _buildCveCard(cve);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCveCard(ThreatCveItem cve) {
    Color scoreColor = AppTheme.safe;
    if (cve.severity == CveSeverity.high) scoreColor = AppTheme.warning;
    if (cve.severity == CveSeverity.critical) scoreColor = AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCveDetailModal(cve),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'CVSS ${cve.cvssScore.toStringAsFixed(1)} ${cve.severity.name.toUpperCase()}',
                      style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cve.vendorName,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    cve.cveId,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                cve.vulnerabilityName,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                cve.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.build_circle_outlined, size: 14, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cve.requiredAction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCveDetailModal(ThreatCveItem cve) {
    Color scoreColor = AppTheme.safe;
    if (cve.severity == CveSeverity.high) scoreColor = AppTheme.warning;
    if (cve.severity == CveSeverity.critical) scoreColor = AppTheme.danger;

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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'CVSS ${cve.cvssScore.toStringAsFixed(1)} ${cve.severity.name.toUpperCase()}',
                      style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    cve.cveId,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(cve.vulnerabilityName,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 12),
              _detailRow('Vendor / Publisher', cve.vendorName),
              _detailRow('Affected Product', cve.productName),
              _detailRow('Exploitation Status', cve.isKnownExploited ? 'ACTIVELY EXPLOITED IN WILD' : 'Known Vulnerability'),
              _detailRow('Published Date', '${cve.publishedDate.day}/${cve.publishedDate.month}/${cve.publishedDate.year}'),
              const SizedBox(height: 14),
              const Text('Vulnerability Description:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(cve.description,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              const Text('Mitigation & Vendor Action:',
                  style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Text(cve.requiredAction,
                    style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(cve.referenceUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Open Official NVD / CISA Advisory'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
