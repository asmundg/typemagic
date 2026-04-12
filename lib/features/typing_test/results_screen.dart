import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/models.dart';
import '../achievements/achievement_system.dart';

class ResultsScreen extends StatelessWidget {
  final TestResult result;
  final VoidCallback onRestart;
  final VoidCallback onRetry;

  const ResultsScreen({
    super.key,
    required this.result,
    required this.onRestart,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Main stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BigStat(
                    label: 'wpm',
                    value: result.wpm.round().toString(),
                    color: AppColors.speedLine,
                  ),
                  _BigStat(
                    label: 'nøyaktighet',
                    value: '${result.accuracy.round()}%',
                    color: AppColors.accent,
                  ),
                ],
              ),
              // Speed badge
              if (speedBadgeForWpm(result.wpm) case final badge?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(badge.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        badge.name,
                        style: AppTheme.monoStyleSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

              // Secondary stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SmallStat(
                        label: 'rå wpm',
                        value: result.rawWpm.round().toString()),
                    _SmallStat(
                        label: 'konsistens',
                        value: '${result.consistency.round()}%'),
                    _SmallStat(
                        label: 'tegn',
                        value:
                            '${result.correctChars}/${result.incorrectChars}'),
                    _SmallStat(
                        label: 'ord', value: '${result.wordCount}'),
                    _SmallStat(
                        label: 'tid',
                        value: _formatDuration(result.duration)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Per-word breakdown
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ordoversikt',
                      style: AppTheme.monoStyleSmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: result.wordResults.length,
                        itemBuilder: (context, index) {
                          final wr = result.wordResults[index];
                          return _WordResultChip(wordResult: wr);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    label: 'prøv igjen',
                    icon: Icons.replay,
                    onTap: onRetry,
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    label: 'nye ord',
                    icon: Icons.refresh,
                    onTap: onRestart,
                    primary: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'tab for nye ord  •  esc for å avbryte',
                style: AppTheme.monoStyleSmall.copyWith(
                  color: AppColors.textSubtle,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BigStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.monoStyle.copyWith(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.monoStyleSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.monoStyleSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.monoStyleSmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _WordResultChip extends StatelessWidget {
  final WordResult wordResult;
  const _WordResultChip({required this.wordResult});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: wordResult.correct
            ? AppColors.surfaceLight.withValues(alpha: 0.5)
            : AppColors.incorrect.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: wordResult.correct
              ? Colors.transparent
              : AppColors.incorrect.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            wordResult.target,
            style: AppTheme.monoStyleSmall.copyWith(
              color: wordResult.correct
                  ? AppColors.correct
                  : AppColors.incorrect,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          if (!wordResult.correct)
            Text(
              wordResult.typed,
              style: AppTheme.monoStyleSmall.copyWith(
                color: AppColors.incorrect.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          Text(
            '${wordResult.wpm.round()} wpm',
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: primary ? AppColors.background : AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTheme.monoStyleSmall.copyWith(
                  color:
                      primary ? AppColors.background : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
