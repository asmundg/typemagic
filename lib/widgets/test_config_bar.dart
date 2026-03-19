import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/models.dart';

class TestConfigBar extends StatelessWidget {
  final TestConfig config;
  final ValueChanged<TestConfig> onConfigChanged;

  const TestConfigBar({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sentence count and mode label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.short_text, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'setninger',
                style: AppTheme.monoStyleSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 20,
                color: AppColors.textSubtle,
              ),
              const SizedBox(width: 16),
              for (final count in [1, 3, 5, 10])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _ValueChip(
                    label: '$count',
                    selected: config.value == count,
                    onTap: () =>
                        onConfigChanged(config.copyWith(value: count)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Difficulty tier selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              for (final tier in DifficultyTier.values)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _TierChip(
                    tier: tier,
                    selected: config.maxTier == tier,
                    onTap: () =>
                        onConfigChanged(config.copyWith(maxTier: tier)),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 16,
                color: AppColors.textSubtle,
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                label: 'æøå',
                active: config.specialCharFocus,
                onTap: () => onConfigChanged(
                  config.copyWith(specialCharFocus: !config.specialCharFocus),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ValueChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: AppTheme.monoStyleSmall.copyWith(
              color: selected ? AppColors.accent : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final DifficultyTier tier;
  final bool selected;
  final VoidCallback onTap;

  const _TierChip({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${tier.displayName}: ${tier.description}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              '${tier.level}',
              style: AppTheme.monoStyleSmall.copyWith(
                color: selected ? AppColors.accent : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: AppTheme.monoStyleSmall.copyWith(
              color: active ? AppColors.accent : AppColors.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
