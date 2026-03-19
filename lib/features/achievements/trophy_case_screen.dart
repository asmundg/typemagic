import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'achievement_system.dart';

/// Full-screen trophy case showing all achievements grouped by category.
class TrophyCaseScreen extends ConsumerWidget {
  const TrophyCaseScreen({super.key});

  static final _dateFormat = DateFormat('d. MMM yyyy', 'nb');
  static final _numberFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementProvider);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Trofékassen',
          style: AppTheme.monoStyleSmall.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Summary header
          _SummaryCard(
            unlocked: unlockedCount,
            total: achievements.length,
          ),
          const SizedBox(height: 20),

          // Grouped by category
          for (final category in AchievementCategory.values) ...[
            _CategoryHeader(category: category),
            const SizedBox(height: 8),
            ...achievements
                .where((a) => a.category == category)
                .map((a) => _AchievementTile(achievement: a)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int unlocked;
  final int total;
  const _SummaryCard({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? unlocked / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            '🏆 $unlocked / $total Troféer',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.xpBarBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% fullført',
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

class _CategoryHeader extends StatelessWidget {
  final AchievementCategory category;
  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Text(
            category.emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Text(
            category.displayName,
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    final opacity = unlocked ? 1.0 : 0.4;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.surface
            : AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: unlocked
            ? Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          // Icon
          Opacity(
            opacity: opacity,
            child: Text(
              achievement.icon,
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 12),

          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: AppTheme.monoStyleSmall.copyWith(
                    color: unlocked
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: AppTheme.monoStyleSmall.copyWith(
                    color: unlocked
                        ? AppColors.textMuted
                        : AppColors.textSubtle,
                    fontSize: 11,
                  ),
                ),
                // Progress bar for locked achievements with trackable progress
                if (!unlocked) _buildProgressIndicator(achievement),
              ],
            ),
          ),

          // Unlock date or lock icon
          if (unlocked && achievement.unlockedAt != null)
            Text(
              TrophyCaseScreen._dateFormat.format(achievement.unlockedAt!),
              style: AppTheme.monoStyleSmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            )
          else if (!unlocked)
            Icon(
              Icons.lock_outline,
              size: 16,
              color: AppColors.textSubtle,
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Achievement achievement) {
    // Show progress for known trackable achievements
    final progress = _getStaticProgress(achievement.id);
    if (progress == null) return const SizedBox.shrink();

    final (current, target) = progress;
    final fraction = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 3,
                backgroundColor: AppColors.xpBarBg,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                      AppColors.xpBar.withValues(alpha: 0.6),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${TrophyCaseScreen._numberFormat.format(current)} / ${TrophyCaseScreen._numberFormat.format(target)}',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.textSubtle,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder progress — in production this would read from StatsAggregates.
  /// Returns null for non-trackable achievements.
  static (int, int)? _getStaticProgress(String id) {
    // These return null to indicate "no progress data available yet".
    // When integrated with the stats system, AchievementProgress.getProgress
    // will provide real values.
    return switch (id) {
      'vol_1' ||
      'vol_1000' ||
      'vol_10000' ||
      'vol_100000' ||
      'streak_3' ||
      'streak_7' ||
      'streak_30' ||
      'streak_100' ||
      'acc_streak_10' ||
      'special_vocab' =>
        null, // Will show progress once stats integration is done
      _ => null,
    };
  }
}
