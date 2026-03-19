import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../progression/xp_system.dart';
import '../stats/stats_repository.dart';
import '../achievements/achievement_system.dart';
import 'settings_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final xpState = ref.watch(xpProvider);
    final tc = ThemeColors.forId(settings.themeId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Innstillinger',
                style: AppTheme.monoStyle.copyWith(
                  color: tc.accent,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 32),

              // — Appearance —
              _SectionHeader(icon: '🎨', label: 'Utseende', color: tc.accent),
              const SizedBox(height: 12),
              _ThemeSelector(
                current: settings.themeId,
                level: xpState.currentLevel,
                colors: tc,
                onSelect: (id) =>
                    ref.read(settingsProvider.notifier).setTheme(id),
              ),
              const SizedBox(height: 16),
              _FontSizeSelector(
                current: settings.fontSize,
                colors: tc,
                onSelect: (s) =>
                    ref.read(settingsProvider.notifier).setFontSize(s),
              ),
              const SizedBox(height: 32),

              // — Sound —
              _SectionHeader(icon: '🔊', label: 'Lyd', color: tc.accent),
              const SizedBox(height: 12),
              _SettingRow(
                label: 'Lyd',
                colors: tc,
                child: Switch(
                  value: settings.soundEnabled,
                  activeThumbColor: tc.accent,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setSoundEnabled(v),
                ),
              ),
              if (settings.soundEnabled) ...[
                const SizedBox(height: 8),
                _SettingRow(
                  label: 'Volum',
                  colors: tc,
                  child: SizedBox(
                    width: 180,
                    child: Slider(
                      value: settings.soundVolume,
                      activeColor: tc.accent,
                      inactiveColor: tc.surfaceLight,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setSoundVolume(v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // — Typing —
              _SectionHeader(icon: '⌨️', label: 'Skriving', color: tc.accent),
              const SizedBox(height: 12),
              _ChipRow(
                label: 'Stopp ved feil',
                options: const ['off', 'letter', 'word'],
                labels: const ['Av', 'Bokstav', 'Ord'],
                selected: settings.stopOnError,
                colors: tc,
                onSelect: (v) =>
                    ref.read(settingsProvider.notifier).setStopOnError(v),
              ),
              const SizedBox(height: 16),
              _ChipRow(
                label: 'Standard testmodus',
                options: const ['time', 'words', 'sentences'],
                labels: const ['Tid', 'Ord', 'Setninger'],
                selected: settings.defaultTestMode,
                colors: tc,
                onSelect: (v) =>
                    ref.read(settingsProvider.notifier).setDefaultTestMode(v),
              ),
              const SizedBox(height: 16),
              _DefaultValueSelector(
                mode: settings.defaultTestMode,
                value: settings.defaultTestValue,
                colors: tc,
                onSelect: (v) =>
                    ref.read(settingsProvider.notifier).setDefaultTestValue(v),
              ),
              const SizedBox(height: 16),
              _TierSelector(
                current: settings.defaultTier,
                colors: tc,
                onSelect: (v) =>
                    ref.read(settingsProvider.notifier).setDefaultTier(v),
              ),
              const SizedBox(height: 32),

              // — Data —
              _SectionHeader(icon: '📊', label: 'Data', color: tc.accent),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Eksporter statistikk',
                icon: Icons.upload_rounded,
                colors: tc,
                enabled: false,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: 'Nullstill alle data',
                icon: Icons.delete_forever_rounded,
                colors: tc,
                destructive: true,
                onTap: () => _confirmReset(context, ref, tc),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref, ThemeColors tc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nullstill alle data?',
          style: TextStyle(color: tc.textPrimary),
        ),
        content: Text(
          'Dette sletter all statistikk, XP og innstillinger. '
          'Denne handlingen kan ikke angres.',
          style: TextStyle(color: tc.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Avbryt', style: TextStyle(color: tc.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(settingsProvider.notifier).resetAll();
              ref.read(statsRepositoryProvider).clearAll();
              ref.read(xpProvider.notifier).reset();
              ref.read(achievementProvider.notifier).reset();
            },
            child: Text('Nullstill',
                style: TextStyle(color: tc.incorrect)),
          ),
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.monoStyleSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}

// ── Generic setting row ─────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  final ThemeColors colors;
  const _SettingRow(
      {required this.label, required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: colors.textPrimary, fontSize: 14)),
        child,
      ],
    );
  }
}

// ── Theme selector ──────────────────────────────────────────

class _ThemeDef {
  final String id;
  final String label;
  final Color preview;
  final Color accent;
  final int requiredLevel;
  const _ThemeDef(
      this.id, this.label, this.preview, this.accent, this.requiredLevel);
}

const _themes = [
  _ThemeDef('dark', 'Mørk', Color(0xFF1a1a2e), Color(0xFFe2b714), 0),
  _ThemeDef('light', 'Lys', Color(0xFFf5f5f5), Color(0xFFd4a017), 0),
  _ThemeDef(
      'northern_lights', 'Nordlys', Color(0xFF0a1628), Color(0xFF00d4aa), 10),
  _ThemeDef('fjord_blue', 'Fjord-blå', Color(0xFF0c1929), Color(0xFF4a9eff), 20),
  _ThemeDef(
      'viking_gold', 'Viking-gull', Color(0xFF1a1408), Color(0xFFc8a654), 35),
];

class _ThemeSelector extends StatelessWidget {
  final String current;
  final int level;
  final ThemeColors colors;
  final ValueChanged<String> onSelect;

  const _ThemeSelector({
    required this.current,
    required this.level,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _themes.map((t) {
        final unlocked = level >= t.requiredLevel;
        final selected = t.id == current;
        return Tooltip(
          message: unlocked
              ? t.label
              : '${t.label} — Lås opp ved nivå ${t.requiredLevel}',
          child: MouseRegion(
            cursor: unlocked
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: GestureDetector(
              onTap: unlocked ? () => onSelect(t.id) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 110,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? t.accent.withValues(alpha: 0.15)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? t.accent
                        : colors.surfaceLight.withValues(alpha: 0.5),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.preview,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: t.accent, width: 2),
                      ),
                      child: unlocked
                          ? null
                          : Icon(Icons.lock_rounded,
                              size: 16, color: colors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.label,
                      style: TextStyle(
                        color: unlocked
                            ? colors.textPrimary
                            : colors.textSubtle,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Font size selector ──────────────────────────────────────

class _FontSizeSelector extends StatelessWidget {
  final String current;
  final ThemeColors colors;
  final ValueChanged<String> onSelect;
  const _FontSizeSelector(
      {required this.current, required this.colors, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _ChipRow(
      label: 'Tekststørrelse',
      options: const ['small', 'medium', 'large'],
      labels: const ['Liten', 'Medium', 'Stor'],
      selected: current,
      colors: colors,
      onSelect: onSelect,
    );
  }
}

// ── Chip row (generic option picker) ────────────────────────

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> labels;
  final String selected;
  final ThemeColors colors;
  final ValueChanged<String> onSelect;

  const _ChipRow({
    required this.label,
    required this.options,
    required this.labels,
    required this.selected,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: colors.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: List.generate(options.length, (i) {
            final active = options[i] == selected;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelect(options[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? colors.accent.withValues(alpha: 0.15)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? colors.accent : colors.surfaceLight,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: active ? colors.accent : colors.textPrimary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Default value selector (changes based on mode) ──────────

class _DefaultValueSelector extends StatelessWidget {
  final String mode;
  final int value;
  final ThemeColors colors;
  final ValueChanged<int> onSelect;

  const _DefaultValueSelector({
    required this.mode,
    required this.value,
    required this.colors,
    required this.onSelect,
  });

  List<int> get _options {
    switch (mode) {
      case 'words':
        return [10, 25, 50, 100];
      case 'sentences':
        return [1, 3, 5, 10];
      default:
        return [15, 30, 60, 120];
    }
  }

  String _label(int v) {
    switch (mode) {
      case 'words':
        return '$v ord';
      case 'sentences':
        return '$v setn.';
      default:
        return '${v}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = _options;
    final effectiveValue = opts.contains(value) ? value : opts[1];
    return _ChipRow(
      label: mode == 'time'
          ? 'Standard varighet'
          : mode == 'words'
              ? 'Standard antall ord'
              : 'Standard antall setninger',
      options: opts.map((o) => o.toString()).toList(),
      labels: opts.map(_label).toList(),
      selected: effectiveValue.toString(),
      colors: colors,
      onSelect: (v) => onSelect(int.parse(v)),
    );
  }
}

// ── Tier selector ───────────────────────────────────────────

class _TierSelector extends StatelessWidget {
  final int current;
  final ThemeColors colors;
  final ValueChanged<int> onSelect;
  const _TierSelector(
      {required this.current, required this.colors, required this.onSelect});

  static const _tierLabels = [
    'Nybegynner',
    'Lærling',
    'Ordsmith',
    'Mester',
    'Trollmann',
  ];

  @override
  Widget build(BuildContext context) {
    return _ChipRow(
      label: 'Standard vanskelighetsgrad',
      options: List.generate(5, (i) => '${i + 1}'),
      labels: _tierLabels,
      selected: '$current',
      colors: colors,
      onSelect: (v) => onSelect(int.parse(v)),
    );
  }
}

// ── Action button ───────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeColors colors;
  final bool destructive;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.colors,
    this.destructive = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? colors.textSubtle
        : destructive
            ? colors.incorrect
            : colors.textPrimary;

    return MouseRegion(
      cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: destructive
                  ? colors.incorrect.withValues(alpha: 0.3)
                  : colors.surfaceLight,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: fg, fontSize: 14)),
              if (!enabled) ...[
                const Spacer(),
                Text('Kommer snart',
                    style: TextStyle(color: colors.textSubtle, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
