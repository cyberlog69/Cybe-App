import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../services/security_score_service.dart';

class SecurityScoreWidget extends StatefulWidget {
  const SecurityScoreWidget({super.key});

  @override
  State<SecurityScoreWidget> createState() => _SecurityScoreWidgetState();
}

class _SecurityScoreWidgetState extends State<SecurityScoreWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  SecurityScoreReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _loadScore();
  }

  Future<void> _loadScore() async {
    final rep = await SecurityScoreService.calculateReport();
    if (!mounted) return;
    setState(() {
      _report = rep;
      _loading = false;
      _anim = Tween<double>(begin: 0, end: rep.totalScore.toDouble())
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    });
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    final score = _report?.totalScore ?? 0;
    return score < 50 ? AppTheme.danger : score < 75 ? AppTheme.warning : AppTheme.safe;
  }

  void _showDetailsModal(BuildContext context) {
    if (_report == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, color: _color, size: 28),
                const SizedBox(width: 12),
                Text('Security Score Breakdown (${_report!.totalScore}/100)',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ..._report!.factors.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(f.title,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${(f.scoreFraction * 100).toInt()}%',
                              style: TextStyle(
                                  color: f.scoreFraction >= 0.75 ? AppTheme.safe : AppTheme.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(f.tip, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _report == null) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E1E30)),
        ),
        child: const CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return GestureDetector(
      onTap: () => _showDetailsModal(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E1E30)),
          boxShadow: [BoxShadow(color: _color.withOpacity(0.08), blurRadius: 20)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, child) {
                  final currentScore = _anim.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 0,
                          centerSpaceRadius: 36,
                          sections: [
                            PieChartSectionData(
                              value: currentScore.clamp(0.1, 100),
                              color: _color,
                              radius: 18,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: (100 - currentScore).clamp(0, 99.9),
                              color: AppTheme.divider,
                              radius: 18,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentScore.toInt().toString(),
                            style: TextStyle(color: _color, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          Text('/100', style: TextStyle(color: _color.withOpacity(0.5), fontSize: 11)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Security Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_report!.ratingLabel, style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._report!.factors.take(4).map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: _factor(f.title, f.scoreFraction, f.scoreFraction >= 0.75 ? AppTheme.safe : AppTheme.warning),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _factor(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }
}
