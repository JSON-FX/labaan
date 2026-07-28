import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'lb_chip.dart';

/// LIVE, READY, SLA countdown — chip variants with a pulsing dot.
class StatusPill extends StatelessWidget {
  const StatusPill.live({super.key})
    : label = 'LIVE',
      color = LbColors.danger,
      dot = true;

  const StatusPill.ready({super.key})
    : label = 'READY NOW',
      color = LbColors.lime,
      dot = true;

  const StatusPill.sla({required this.label, super.key})
    : color = LbColors.danger,
      dot = true;

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            PulseDot(color: color, size: 5),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: LbType.metaSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
