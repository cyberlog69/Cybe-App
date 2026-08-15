import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cybe_app/core/theme/app_theme.dart';

enum CybeLogoVariant {
  iconOnly,
  horizontal,
  vertical,
}

enum CybeLogoStyle {
  svgAsset,
  materialIcon,
}

/// A versatile, futuristic Material 3 Cyber Security Logo widget.
/// Supports both SVG vector rendering and layered Material 3 Icon + Glowing Neon Shield.
class CybeLogo extends StatelessWidget {
  final CybeLogoVariant variant;
  final CybeLogoStyle style;
  final double size;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Gradient gradient;
  final bool isGlowing;
  final bool showText;
  final VoidCallback? onTap;

  const CybeLogo({
    super.key,
    this.variant = CybeLogoVariant.horizontal,
    this.style = CybeLogoStyle.materialIcon,
    this.size = 36,
    this.title = 'CYBE',
    this.subtitle,
    this.icon = Icons.security_rounded,
    this.gradient = AppTheme.primaryGradient,
    this.isGlowing = true,
    this.showText = true,
    this.onTap,
  });

  /// Preset for AppBar / Navigation headers
  const CybeLogo.appBar({
    super.key,
    this.size = 34,
    this.title = 'CYBE',
    this.subtitle,
    this.icon = Icons.security_rounded,
    this.gradient = AppTheme.primaryGradient,
    this.style = CybeLogoStyle.materialIcon,
    this.onTap,
  })  : variant = CybeLogoVariant.horizontal,
        isGlowing = true,
        showText = true;

  /// Preset for Hero screens (Lock screen, Setup, Welcome, Splash)
  const CybeLogo.hero({
    super.key,
    this.size = 96,
    this.title = 'CYBE',
    this.subtitle = 'SECURITY SUITE',
    this.icon = Icons.security_rounded,
    this.gradient = AppTheme.primaryGradient,
    this.style = CybeLogoStyle.materialIcon,
    this.onTap,
  })  : variant = CybeLogoVariant.vertical,
        isGlowing = true,
        showText = true;

  /// Preset for standalone icon emblem
  const CybeLogo.iconOnly({
    super.key,
    this.size = 48,
    this.icon = Icons.security_rounded,
    this.gradient = AppTheme.primaryGradient,
    this.style = CybeLogoStyle.materialIcon,
    this.isGlowing = true,
    this.onTap,
  })  : variant = CybeLogoVariant.iconOnly,
        title = '',
        subtitle = null,
        showText = false;

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (variant) {
      case CybeLogoVariant.iconOnly:
        content = _buildEmblem(context);
        break;

      case CybeLogoVariant.horizontal:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildEmblem(context),
            if (showText && title.isNotEmpty) ...[
              SizedBox(width: size * 0.32),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleText(fontSize: size * 0.62, letterSpacing: size * 0.16),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    _buildSubtitleText(fontSize: size * 0.28, letterSpacing: size * 0.12),
                ],
              ),
            ],
          ],
        );
        break;

      case CybeLogoVariant.vertical:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildEmblem(context),
            if (showText && title.isNotEmpty) ...[
              SizedBox(height: size * 0.28),
              _buildTitleText(fontSize: size * 0.46, letterSpacing: size * 0.22),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildSubtitleText(fontSize: size * 0.14, letterSpacing: size * 0.08),
              ],
            ],
          ],
        );
        break;
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }

  Widget _buildEmblem(BuildContext context) {
    if (style == CybeLogoStyle.svgAsset) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          'assets/icons/cybe_logo.svg',
          fit: BoxFit.contain,
        ),
      );
    }

    // Material 3 Cyberpunk Glowing Emblem
    final double iconSize = size * 0.52;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: isGlowing
          ? [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: size * 0.35,
                spreadRadius: size * 0.05,
              ),
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.25),
                blurRadius: size * 0.5,
              ),
            ]
          : null,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTitleText({required double fontSize, required double letterSpacing}) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: letterSpacing,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildSubtitleText({required double fontSize, required double letterSpacing}) {
    return Text(
      subtitle!,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
        height: 1.2,
      ),
    );
  }
}
