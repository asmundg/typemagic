import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../stats/stats_repository.dart';
import 'touch_exercises.dart';
import 'drill_screen.dart';

class TrainingMenuScreen extends ConsumerWidget {
  const TrainingMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(statsRepositoryProvider);
    final keyStats = repo.getKeyStatsAggregate();

    // Find the weakest keys (min 10 presses, worst accuracy)
    final weakKeys = <String>{};
    final ranked = keyStats.entries
        .where((e) => e.value.total >= 10)
        .toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    for (final entry in ranked.take(5)) {
      if (entry.value.accuracy < 0.95) {
        weakKeys.add(entry.key);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Tastaturtrening',
                  style: AppTheme.monoStyleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Velg en øvelse for å trene fingerposisjon',
                  style: AppTheme.monoStyleSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _ExerciseGrid(
                    keyStats: keyStats,
                    weakKeys: weakKeys,
                  ),
                ),
                const SizedBox(height: 16),
                _Legend(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseGrid extends StatelessWidget {
  final Map<String, KeyStats> keyStats;
  final Set<String> weakKeys;

  const _ExerciseGrid({required this.keyStats, required this.weakKeys});

  @override
  Widget build(BuildContext context) {
    // Build a 2D grid from exercise row/col
    final grid = List.generate(
      exerciseGridRows,
      (_) => List<TouchExercise?>.filled(exerciseGridCols, null),
    );
    for (final ex in touchExercises) {
      grid[ex.row][ex.col] = ex;
    }

    final rowLabels = ['Hvileraden', 'Øvre rad', 'Nedre rad', 'Kombinert'];

    return ListView.builder(
      itemCount: exerciseGridRows,
      itemBuilder: (context, row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  rowLabels[row],
                  style: AppTheme.monoStyleSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var col = 0; col < exerciseGridCols; col++) ...[
                    if (col > 0) const SizedBox(width: 8),
                    Expanded(
                      child: grid[row][col] != null
                          ? _ExerciseCard(
                              exercise: grid[row][col]!,
                              keyStats: keyStats,
                              weakKeys: weakKeys,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final TouchExercise exercise;
  final Map<String, KeyStats> keyStats;
  final Set<String> weakKeys;

  const _ExerciseCard({
    required this.exercise,
    required this.keyStats,
    required this.weakKeys,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _aggregateExerciseStats();
    final color = _heatmapColor(stats);
    final isRecommended =
        exercise.keys.any((k) => weakKeys.contains(k));

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _startDrill(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRecommended
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : color.withValues(alpha: 0.3),
              width: isRecommended ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: AppTheme.monoStyleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'anbefalt',
                        style: AppTheme.monoStyleSmall.copyWith(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Key preview
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: exercise.keys
                    .map((k) => _KeyChip(
                          letter: k,
                          keyStats: keyStats[k],
                        ))
                    .toList(),
              ),
              if (stats != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(stats * 100).round()}%',
                      style: AppTheme.monoStyleSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Average accuracy across this exercise's keys (null if no data).
  double? _aggregateExerciseStats() {
    int totalCorrect = 0;
    int totalAll = 0;
    for (final k in exercise.keys) {
      final s = keyStats[k];
      if (s != null) {
        totalCorrect += s.correct;
        totalAll += s.total;
      }
    }
    if (totalAll == 0) return null;
    return totalCorrect / totalAll;
  }

  Color _heatmapColor(double? accuracy) {
    if (accuracy == null) return AppColors.textSubtle;
    if (accuracy >= 0.95) return AppColors.correct;
    if (accuracy >= 0.80) return const Color(0xFFE2B93D);
    return AppColors.incorrect;
  }

  void _startDrill(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrillScreen(exercise: exercise),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  final String letter;
  final KeyStats? keyStats;

  const _KeyChip({required this.letter, this.keyStats});

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (keyStats == null || keyStats!.total == 0) {
      bg = AppColors.surfaceLight.withValues(alpha: 0.5);
    } else {
      final acc = keyStats!.accuracy;
      if (acc >= 0.95) {
        bg = AppColors.correct.withValues(alpha: 0.2);
      } else if (acc >= 0.80) {
        bg = const Color(0xFFE2B93D).withValues(alpha: 0.2);
      } else {
        bg = AppColors.incorrect.withValues(alpha: 0.2);
      }
    }

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        letter,
        style: AppTheme.monoStyleSmall.copyWith(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: AppColors.textSubtle, label: 'Ingen data'),
        const SizedBox(width: 16),
        _LegendItem(color: AppColors.incorrect, label: '<80%'),
        const SizedBox(width: 16),
        _LegendItem(color: const Color(0xFFE2B93D), label: '80-95%'),
        const SizedBox(width: 16),
        _LegendItem(color: AppColors.correct, label: '≥95%'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.monoStyleSmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
