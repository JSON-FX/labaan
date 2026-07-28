import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The workhorse dark card — flat #1A1D24 with a 1-px #31353F border and a
/// 10–12 px radius. When [highlighted] is true it takes the lime treatment
/// used for "primary action" cards (Match Ready, Payment method selected,
/// Winner in score entry, etc.).
class LbCard extends StatelessWidget {
  const LbCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 12,
    this.highlighted = false,
    this.onTap,
    this.overlayGradient = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool highlighted;
  final VoidCallback? onTap;
  final bool overlayGradient;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: highlighted ? null : LbColors.surface,
      gradient: highlighted
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                LbColors.lime.withValues(alpha: 0.08),
                LbColors.lime.withValues(alpha: 0.02),
              ],
            )
          : overlayGradient
          ? LinearGradient(
              colors: [
                LbColors.surface,
                LbColors.surface.withValues(alpha: 0.7),
              ],
            )
          : null,
      border: Border.all(
        color: highlighted ? LbColors.lime : LbColors.border,
        width: highlighted ? 1.5 : 1,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: highlighted
          ? [
              BoxShadow(
                color: LbColors.lime.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: -6,
              ),
            ]
          : null,
    );

    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
