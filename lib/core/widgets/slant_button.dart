import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// The lime CTA with the notched bottom-right corner + glow.
///
/// Clips a rectangle with the corner cut off:
///   polygon(0 0, 100% 0, 100% (h-notch), (w-notch) 100%, 0 100%)
class SlantButton extends StatelessWidget {
  const SlantButton({
    required this.label,
    required this.onPressed,
    this.trailing,
    this.leading,
    this.height = 48,
    this.notch = 10,
    this.color = LbColors.lime,
    this.foreground = LbColors.limeInk,
    this.glow = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final double notch;
  final Color color;
  final Color foreground;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final effectiveColor = disabled ? color.withValues(alpha: 0.35) : color;
    final effectiveForeground = disabled
        ? foreground.withValues(alpha: 0.5)
        : foreground;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: LbType.button.copyWith(color: effectiveForeground),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );

    return DecoratedBox(
      decoration: (glow && !disabled)
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            )
          : const BoxDecoration(),
      child: ClipPath(
        clipper: _SlantClipper(notch: notch),
        child: Material(
          color: effectiveColor,
          child: Semantics(
            button: true,
            enabled: !disabled,
            label: label,
            child: InkWell(
              onTap: onPressed == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlantClipper extends CustomClipper<Path> {
  const _SlantClipper({required this.notch});
  final double notch;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - notch);
    path.lineTo(size.width - notch, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _SlantClipper oldClipper) =>
      oldClipper.notch != notch;
}

/// Ghost / secondary button — plain outlined rectangle with Chakra Petch upper.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    this.leading,
    this.height = 42,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: LbColors.border),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Text(
              label.toUpperCase(),
              style: LbType.button.copyWith(color: LbColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
