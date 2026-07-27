import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class SecurityScoreWidget extends StatefulWidget {
  const SecurityScoreWidget({super.key});
  @override
  State<SecurityScoreWidget> createState() => _SecurityScoreWidgetState();
}

class _SecurityScoreWidgetState extends State<SecurityScoreWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  final double _score = 72;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _anim = Tween<double>(begin: 0, end: _score)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _color => _score < 40 ? AppTheme.danger : _score < 70 ? AppTheme.warning : AppTheme.safe;
  String get _label => _score < 40 ? 'At Risk' : _score < 70 ? 'Needs Attention' : 'Well Protected';

  @override
  Widget build(BuildContext context) {
    return Container(
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
            width: 110, height: 110,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 36,
                    sections: [
                      PieChartSectionData(value: _anim.value, color: _color, radius: 18, showTitle: false),
                      PieChartSectionData(value: 100 - _anim.value, color: AppTheme.divider, radius: 18, showTitle: false),
                    ],
                  )),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _anim.value.toInt().toString(),
                        style: TextStyle(color: _color, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      Text('/100', style: TextStyle(color: _color.withOpacity(0.5), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security Score',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(_label,
                  style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _factor('Passwords', 0.8, AppTheme.safe),
                const SizedBox(height: 6),
                _factor('Wi-Fi', 0.5, AppTheme.warning),
                const SizedBox(height: 6),
                _factor('Device', 0.7, AppTheme.safe),
                const SizedBox(height: 6),
                _factor('Files', 0.9, AppTheme.safe),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factor(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
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
