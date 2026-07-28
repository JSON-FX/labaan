import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// A 3-letter team monogram square with a gradient. The design uses this on
/// every team reference — bracket rows, invites, score steppers.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({
    required this.code,
    this.size = 26,
    this.gradient,
    super.key,
  });

  final String code;
  final double size;
  final List<Color>? gradient;

  static const _defaults = <String, List<Color>>{
    'MNL': [Color(0xFFFF4655), Color(0xFFA01727)],
    'CBU': [Color(0xFF1A2540), Color(0xFF0A1020)],
    'DVO': [Color(0xFF1A2540), Color(0xFF0A1020)],
  };

  @override
  Widget build(BuildContext context) {
    final colors =
        gradient ??
        _defaults[code] ??
        const [LbColors.info, LbColors.mlbbStart];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        code.substring(0, code.length.clamp(0, 3)),
        style: LbType.rankNumeral(size * 0.34, color: Colors.white),
      ),
    );
  }
}
