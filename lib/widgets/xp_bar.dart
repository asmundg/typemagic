import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../features/progression/xp_system.dart';

/// Compact horizontal XP progress bar for the top of the typing screen.
class XPBar extends ConsumerWidget {
  const XPBar({super.key});

  static final _numberFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = ref.watch(xpProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          // Level badge + title
          _LevelBadge(level: xp.currentLevel),
          const SizedBox(width: 8),
          Text(
            xp.currentTitle,
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),

          // Progress bar
          Expanded(
            child: _ProgressBar(progress: xp.xpProgress),
          ),

          const SizedBox(width: 12),

          // XP text
          Text(
            '${_numberFormat.format(xp.xpInCurrentLevel)} / ${_numberFormat.format(xp.xpBandSize)} XP',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.xpBar.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.xpBar.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        'Lv $level',
        style: AppTheme.monoStyleSmall.copyWith(
          color: AppColors.xpBar,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.xpBarBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: fillWidth,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.xpBar, AppColors.speedLine],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.xpBar.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
