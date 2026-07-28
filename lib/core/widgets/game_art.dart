import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// The design's game "key-art" placeholder — a diagonal gradient with a
/// hatched overlay and a mono-font game code in the corner.
///
/// e.g. VALORANT, MLBB, TEKKEN 8. Real key-art bitmaps will replace these
/// once the asset pipeline lands.
class GameArt extends StatelessWidget {
  const GameArt({
    required this.game,
    this.width = 56,
    this.height = 46,
    this.radius = 7,
    this.hatchAngle = 135,
    this.showLabel = true,
    super.key,
  });

  /// Shorthand controls the gradient palette (see [_paletteFor]) and the
  /// label the corner displays.
  final String game;
  final double width;
  final double height;
  final double radius;
  final double hatchAngle;

  /// When false, the corner game-code label is suppressed. Use false on
  /// hero-sized instances where the title/subtitle already state the game.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(game);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _HatchPainter(angle: hatchAngle)),
              if (showLabel)
                Positioned(
                  left: 4,
                  bottom: 3,
                  child: Text(
                    game.toUpperCase(),
                    style: LbType.metaSm.copyWith(
                      color: LbColors.textPrimary,
                      fontSize: 7.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Color> _paletteFor(String game) {
    switch (game.toUpperCase()) {
      case 'VALORANT':
      case 'ART · VAL':
      case 'VAL':
        return const [LbColors.valStart, LbColors.valMid, LbColors.valEnd];
      case 'MLBB':
        return const [LbColors.mlbbStart, LbColors.mlbbMid, LbColors.mlbbEnd];
      case 'TEKKEN 8':
      case 'TEKKEN':
        return const [
          LbColors.tekkenStart,
          LbColors.tekkenMid,
          LbColors.tekkenEnd,
        ];
      default:
        return const [Color(0xFF1A2540), Color(0xFF0A1020), Color(0xFF4A90C8)];
    }
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.angle});
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 5;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle * 3.1415926 / 180);
    final diag = size.longestSide * 1.6;
    for (double x = -diag; x < diag; x += 10) {
      canvas.drawLine(Offset(x, -diag), Offset(x, diag), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => false;
}
