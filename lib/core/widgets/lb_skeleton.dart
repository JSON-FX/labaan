import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Pulsing shimmer block. Use in place of a plain grey rectangle when a
/// screen is waiting on data.
class LbSkeleton extends StatefulWidget {
  const LbSkeleton({
    this.height = 60,
    this.width = double.infinity,
    this.radius = 11,
    super.key,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<LbSkeleton> createState() => _LbSkeletonState();
}

class _LbSkeletonState extends State<LbSkeleton>
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
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1..0
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 2, 0),
                end: Alignment(1 + t * 2, 0),
                colors: const [
                  LbColors.surface,
                  Color(0xFF22262E),
                  LbColors.surface,
                ],
              ),
              border: Border.all(color: LbColors.borderMuted),
            ),
          );
        },
      ),
    );
  }
}

/// Stack of shimmers approximating a card + several rows below it. Drop-in
/// replacement for a screen's `_Skeleton` widget.
class LbSkeletonStack extends StatelessWidget {
  const LbSkeletonStack({this.rows = 4, super.key});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const LbSkeleton(height: 120),
          const SizedBox(height: 12),
          for (var i = 0; i < rows; i++) ...[
            const LbSkeleton(height: 60),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
