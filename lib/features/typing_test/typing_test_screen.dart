import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/models.dart';
import 'typing_test_state.dart';
import 'results_screen.dart';
import '../../widgets/test_config_bar.dart';
import '../../widgets/xp_bar.dart';

class TypingTestScreen extends ConsumerStatefulWidget {
  const TypingTestScreen({super.key});

  @override
  ConsumerState<TypingTestScreen> createState() => _TypingTestScreenState();
}

class _TypingTestScreenState extends ConsumerState<TypingTestScreen> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final notifier = ref.read(typingTestProvider.notifier);
    final state = ref.read(typingTestProvider);

    // Tab to restart
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      notifier.restart();
      return;
    }

    // Escape to reset
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      notifier.restart();
      return;
    }

    if (state.phase == TypingPhase.finished) return;

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      notifier.onBackspace();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      notifier.onSpace();
    } else if (event.character != null &&
        event.character!.length == 1 &&
        !event.character!.contains(RegExp(r'[\x00-\x1F]'))) {
      notifier.onChar(event.character!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testState = ref.watch(typingTestProvider);

    if (testState.phase == TypingPhase.finished && testState.result != null) {
      return ResultsScreen(
        result: testState.result!,
        onRestart: () => ref.read(typingTestProvider.notifier).restart(),
        onRetry: () => ref.read(typingTestProvider.notifier).retry(),
      );
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // XP progress bar
                  const XPBar(),
                  const SizedBox(height: 16),

                  // Test config bar
                  TestConfigBar(
                    config: testState.config,
                    onConfigChanged: (config) =>
                        ref.read(typingTestProvider.notifier).setConfig(config),
                  ),
                  const SizedBox(height: 24),

                  // Live stats
                  _LiveStatsBar(state: testState),
                  const SizedBox(height: 32),

                  // Words display
                  _WordsDisplay(state: testState),
                  const SizedBox(height: 48),

                  // Hint text
                  if (testState.phase == TypingPhase.waiting)
                    Text(
                      'Begynn å skrive...',
                      style: AppTheme.monoStyleSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (testState.phase == TypingPhase.running)
                    Text(
                      'tab for å starte på nytt',
                      style: AppTheme.monoStyleSmall.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveStatsBar extends StatelessWidget {
  final TypingTestState state;
  const _LiveStatsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.phase == TypingPhase.waiting) {
      return const SizedBox(height: 40);
    }

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.config.mode == TestMode.time) ...[
            _StatChip(
              label: '${state.timeLeft}',
              color: AppColors.accent,
              fontSize: 28,
            ),
            const SizedBox(width: 32),
          ],
          _StatChip(
            label: '${state.liveWpm.round()}',
            suffix: ' wpm',
            color: AppColors.speedLine,
          ),
          const SizedBox(width: 24),
          _StatChip(
            label: '${state.liveAccuracy.round()}',
            suffix: '%',
            color: state.liveAccuracy >= 95
                ? AppColors.speedLine
                : state.liveAccuracy >= 80
                    ? AppColors.accent
                    : AppColors.incorrect,
          ),
          if (state.config.mode == TestMode.words) ...[
            const SizedBox(width: 24),
            _StatChip(
              label: '${state.currentWordIndex}',
              suffix: '/${state.config.value}',
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String? suffix;
  final Color color;
  final double fontSize;

  const _StatChip({
    required this.label,
    this.suffix,
    required this.color,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: AppTheme.monoStyle.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (suffix != null)
          Text(
            suffix!,
            style: AppTheme.monoStyleSmall.copyWith(
              color: color.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
      ],
    );
  }
}

class _WordsDisplay extends StatelessWidget {
  final TypingTestState state;
  const _WordsDisplay({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Wrap(
        spacing: 0, // we handle spacing manually for cursor-on-space
        runSpacing: 8,
        children: [
          for (var i = 0; i < state.words.length && i < state.currentWordIndex + 40; i++) ...[
            _WordWidget(
              word: state.words[i],
              isCurrent: i == state.currentWordIndex,
              isPast: i < state.currentWordIndex,
            ),
            // Space between words — show cursor underline if current word is fully typed
            _SpaceWidget(
              showCursor: i == state.currentWordIndex &&
                  state.words[i].typed.length >= state.words[i].target.length,
            ),
          ],
        ],
      ),
    );
  }
}

class _WordWidget extends StatelessWidget {
  final TestWord word;
  final bool isCurrent;
  final bool isPast;

  const _WordWidget({
    required this.word,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTheme.monoStyle,
        children: [
          for (var i = 0; i < word.target.length; i++)
            TextSpan(
              text: word.target[i],
              style: TextStyle(
                color: _charColor(i),
                decoration: _isAtCursor(i)
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: AppColors.cursor,
                decorationThickness: 2.5,
              ),
            ),
          // Show extra typed characters
          if (word.typed.length > word.target.length)
            TextSpan(
              text: word.typed.toString().substring(word.target.length),
              style: const TextStyle(color: AppColors.extra),
            ),
        ],
      ),
    );
  }

  bool _isAtCursor(int index) {
    return isCurrent && index == word.typed.length;
  }

  Color _charColor(int index) {
    if (isPast) {
      return word.charStates[index] == CharState.correct
          ? AppColors.correct
          : AppColors.incorrect;
    }
    if (!isCurrent) return AppColors.textMuted;

    // Current word — already typed characters
    if (index < word.typed.length) {
      return word.charStates[index] == CharState.correct
          ? AppColors.correct
          : AppColors.incorrect;
    }

    // Cursor position — next character to type
    if (index == word.typed.length) {
      return AppColors.textPrimary;
    }

    return AppColors.textMuted;
  }
}

class _SpaceWidget extends StatelessWidget {
  final bool showCursor;
  const _SpaceWidget({required this.showCursor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      child: showCursor
          ? Text(
              ' ',
              style: AppTheme.monoStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.cursor,
                decorationThickness: 2.5,
              ),
            )
          : null,
    );
  }
}
