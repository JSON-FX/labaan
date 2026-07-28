import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

enum LbChipTone { neutral, lime, gold, danger }

/// Compact uppercase tag — ELITE / PREMIUM / COMMUNITY / LIVE etc.
class LbChip extends StatelessWidget {
  const LbChip(
    this.label, {
    this.tone = LbChipTone.neutral,
    this.leading,
    super.key,
  });

  final String label;
  final LbChipTone tone;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = switch (tone) {
      LbChipTone.lime => (
        LbColors.lime,
        LbColors.lime.withValues(alpha: 0.05),
        LbColors.lime,
      ),
      LbChipTone.gold => (
        LbColors.gold,
        LbColors.gold.withValues(alpha: 0.06),
        LbColors.gold,
      ),
      LbChipTone.danger => (
        LbColors.danger,
        LbColors.danger.withValues(alpha: 0.06),
        LbColors.danger.withValues(alpha: 0.5),
      ),
      LbChipTone.neutral => (
        LbColors.textSecondary,
        Colors.white.withValues(alpha: 0.02),
        LbColors.textDim,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(
            label.toUpperCase(),
            style: LbType.metaSm.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Little pulsing dot used inside LIVE / SLA chips.
class PulseDot extends StatefulWidget {
  const PulseDot({this.color = LbColors.danger, this.size = 6, super.key});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(_c),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
