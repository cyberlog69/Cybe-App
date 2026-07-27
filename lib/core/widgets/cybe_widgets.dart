import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Reusable glassy card with optional neon accent border
class CybeCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const CybeCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: accentColor?.withOpacity(0.4) ?? const Color(0xFF1E1E30),
          width: accentColor != null ? 1.5 : 1,
        ),
        boxShadow: accentColor != null
            ? [BoxShadow(color: accentColor!.withOpacity(0.1), blurRadius: 16)]
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Status badge with colored dot and label
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Animated scanning radar widget
class ScanningAnimation extends StatefulWidget {
  final Color color;
  final double size;
  const ScanningAnimation({super.key, this.color = AppTheme.primary, this.size = 80});

  @override
  State<ScanningAnimation> createState() => _ScanningAnimationState();
}

class _ScanningAnimationState extends State<ScanningAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: SizedBox(
        width: widget.size, height: widget.size,
        child: CustomPaint(painter: _RadarPainter(color: widget.color)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  _RadarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..color = color.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.66, paint);
    canvas.drawCircle(center, radius * 0.33, paint);

    // Radar sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(colors: [color.withOpacity(0.0), color.withOpacity(0.4)]).createShader(
        Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57, 1.57, true, sweepPaint);

    // Center dot
    canvas.drawCircle(center, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Gradient text widget
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(this.text, {super.key, required this.style, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
