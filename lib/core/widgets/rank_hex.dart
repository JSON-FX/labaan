import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Six-sided rank badge with a "seed" number inside.
///
/// The design uses `clip-path: polygon(50% 0, 100% 25%, 100% 75%, 50% 100%,
/// 0 75%, 0 25%)` — a flat-top hex.
class RankHex extends StatelessWidget {
  const RankHex({
    required this.rank,
    this.size = 40,
    this.color = LbColors.lime,
    this.textColor = LbColors.textPrimary,
    this.numeralScale = 0.42,
    super.key,
  });

  final int rank;
  final double size;
  final Color color;
  final Color textColor;
  final double numeralScale;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _HexClipper(),
      child: SizedBox(
        width: size,
        height: size * 1.1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.9), LbColors.surfaceHi],
            ),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: LbType.rankNumeral(size * numeralScale, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
