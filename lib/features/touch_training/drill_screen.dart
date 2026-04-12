import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/models.dart';
import '../../widgets/words_display.dart';
import '../../widgets/hand_guide.dart';
import '../typing_test/typing_test_state.dart';
import '../achievements/achievement_system.dart';
import 'touch_exercises.dart';

/// Screen that runs a single drill exercise using the shared typing engine.
class DrillScreen extends ConsumerStatefulWidget {
  final TouchExercise exercise;
  const DrillScreen({super.key, required this.exercise});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  final _focusNode = FocusNode();
  bool _initialized = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _initDrill() {
    if (_initialized) return;
    _initialized = true;
    final words = generateDrillWords(widget.exercise.keys, count: 20);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(typingTestProvider.notifier).startDrill(words);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    final notifier = ref.read(typingTestProvider.notifier);
    final state = ref.read(typingTestProvider);

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _initialized = false;
      _initDrill();
      return KeyEventResult.handled;
    }

    if (state.phase == TypingPhase.finished) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _initialized = false;
        _initDrill();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      notifier.onBackspace();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      notifier.onSpace();
    } else if (event.character != null &&
        event.character!.length == 1 &&
        !event.character!.contains(RegExp(r'[\x00-\x1F]'))) {
      notifier.onChar(event.character!);
    }

    return KeyEventResult.handled;
  }

  /// The key that the user should type next (for highlighting on the guide).
  String? _nextKey(TypingTestState state) {
    if (state.phase == TypingPhase.finished) return null;
    final word = state.currentWord;
    if (word == null) return null;
    final pos = word.typed.length;
    if (pos >= word.target.length) return null;
    return word.target[pos].toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    _initDrill();
    final testState = ref.watch(typingTestProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    Row(
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.exercise.name,
                          style: AppTheme.monoStyleSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Live stats
                    if (testState.phase == TypingPhase.running)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${testState.liveWpm.round()} wpm',
                              style: AppTheme.monoStyleSmall.copyWith(
                                color: AppColors.speedLine,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              '${testState.liveAccuracy.round()}%',
                              style: AppTheme.monoStyleSmall.copyWith(
                                color: AppColors.accent,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Shared words display (same as main typing test)
                    if (testState.phase != TypingPhase.finished)
                      WordsDisplay(state: testState),

                    // Results
                    if (testState.phase == TypingPhase.finished &&
                        testState.result != null)
                      _DrillResults(
                        result: testState.result!,
                        exercise: widget.exercise,
                      ),

                    const SizedBox(height: 24),

                    // Hand guide + finger guide keyboard
                    HandGuide(
                      activeFinger: _nextKey(testState) != null
                          ? keyToFinger[_nextKey(testState)!]
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _FingerGuideKeyboard(
                      activeKeys: Set.from(widget.exercise.keys),
                      nextKey: _nextKey(testState),
                    ),

                    const SizedBox(height: 16),

                    // Hints
                    if (testState.phase == TypingPhase.waiting)
                      Text(
                        'Begynn å skrive...',
                        style: AppTheme.monoStyleSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (testState.phase == TypingPhase.running)
                      Text(
                        'esc tilbake  •  tab nye ord',
                        style: AppTheme.monoStyleSmall.copyWith(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    if (testState.phase == TypingPhase.finished)
                      Text(
                        'enter nye ord  •  esc tilbake',
                        style: AppTheme.monoStyleSmall.copyWith(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Finger guide keyboard
// ---------------------------------------------------------------------------

const _kbRows = [
  ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 'å'],
  ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ø', 'æ'],
  ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
];

class _FingerGuideKeyboard extends StatelessWidget {
  final Set<String> activeKeys;
  final String? nextKey;

  const _FingerGuideKeyboard({
    required this.activeKeys,
    this.nextKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < _kbRows.length; r++)
          Padding(
            padding: EdgeInsets.only(
              left: r == 1 ? 16 : (r == 2 ? 40 : 0),
              bottom: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in _kbRows[r]) ...[
                  _GuideKey(
                    letter: key,
                    isActive: activeKeys.contains(key),
                    isNext: key == nextKey,
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GuideKey extends StatelessWidget {
  final String letter;
  final bool isActive;
  final bool isNext;

  const _GuideKey({
    required this.letter,
    required this.isActive,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final finger = keyToFinger[letter];
    final fingerColor =
        finger != null ? fingerColors[finger]! : AppColors.textSubtle;

    Color bg;
    Color textColor;
    double borderWidth = 0;
    Color borderColor = Colors.transparent;

    if (isNext) {
      bg = fingerColor.withValues(alpha: 0.5);
      textColor = AppColors.textPrimary;
      borderWidth = 2;
      borderColor = fingerColor;
    } else if (isActive) {
      bg = fingerColor.withValues(alpha: 0.15);
      textColor = AppColors.textPrimary;
    } else {
      bg = AppColors.surface.withValues(alpha: 0.3);
      textColor = AppColors.textSubtle;
    }

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: Text(
        letter,
        style: AppTheme.monoStyleSmall.copyWith(
          color: textColor,
          fontSize: 14,
          fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drill results
// ---------------------------------------------------------------------------

class _DrillResults extends StatelessWidget {
  final TestResult result;
  final TouchExercise exercise;

  const _DrillResults({
    required this.result,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final badge = speedBadgeForWpm(result.wpm);

    return Column(
      children: [
        if (badge != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatColumn(
                value: '${result.wpm.round()}',
                label: 'wpm',
                color: AppColors.speedLine,
              ),
              const SizedBox(width: 48),
              _StatColumn(
                value: '${result.accuracy.round()}%',
                label: 'nøyaktighet',
                color: AppColors.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _KeyBreakdown(result: result, keys: exercise.keys),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.monoStyle.copyWith(
            fontSize: 36,
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

class _KeyBreakdown extends StatelessWidget {
  final TestResult result;
  final List<String> keys;

  const _KeyBreakdown({required this.result, required this.keys});

  @override
  Widget build(BuildContext context) {
    final entries = keys
        .where((k) => result.keyStats.containsKey(k))
        .map((k) => MapEntry(k, result.keyStats[k]!))
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.map((e) {
        final acc = e.value.accuracy;
        final finger = keyToFinger[e.key];
        final fingerColor =
            finger != null ? fingerColors[finger]! : AppColors.textSubtle;

        Color bg;
        if (acc >= 0.95) {
          bg = AppColors.correct.withValues(alpha: 0.2);
        } else if (acc >= 0.80) {
          bg = const Color(0xFFE2B93D).withValues(alpha: 0.2);
        } else {
          bg = AppColors.incorrect.withValues(alpha: 0.2);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: fingerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '${e.key} ${(acc * 100).round()}%',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}
