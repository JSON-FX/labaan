import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// The bottom-tab shell: HOME · BROWSE · COMPETE · RANKS · PROFILE.
///
/// Backed by StatefulShellRoute so each tab preserves its own navigation
/// stack.
class MainShell extends StatelessWidget {
  const MainShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _tabs = [
    _TabDef(label: 'HOME', icon: Icons.home_rounded),
    _TabDef(label: 'BROWSE', icon: Icons.explore_rounded),
    _TabDef(label: 'COMPETE', icon: Icons.emoji_events_rounded),
    _TabDef(label: 'RANKS', icon: Icons.leaderboard_rounded),
    _TabDef(label: 'PROFILE', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: LbColors.bg,
          border: Border(top: BorderSide(color: LbColors.borderMuted)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      def: _tabs[i],
                      active: shell.currentIndex == i,
                      onTap: () => shell.goBranch(
                        i,
                        initialLocation: i == shell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  const _TabDef({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.def,
    required this.active,
    required this.onTap,
  });

  final _TabDef def;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? LbColors.lime : LbColors.textDim;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Semantics(
        button: true,
        selected: active,
        label: def.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: active ? LbColors.lime : Colors.transparent,
                  border: active ? null : Border.all(color: color, width: 1.6),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: LbColors.lime.withValues(alpha: 0.9),
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  def.icon,
                  size: 14,
                  color: active ? LbColors.limeInk : color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                def.label,
                style: LbType.metaSm.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
