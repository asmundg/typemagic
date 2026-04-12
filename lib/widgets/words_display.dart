import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../features/typing_test/typing_test_state.dart';

/// Shared word display used by both the main typing test and drill screens.
class WordsDisplay extends StatelessWidget {
  final TypingTestState state;
  final double height;
  const WordsDisplay({super.key, required this.state, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Wrap(
        spacing: 0,
        runSpacing: 8,
        children: [
          for (var i = 0;
              i < state.words.length && i < state.currentWordIndex + 40;
              i++) ...[
            _WordWidget(
              word: state.words[i],
              isCurrent: i == state.currentWordIndex,
              isPast: i < state.currentWordIndex,
            ),
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

    if (index < word.typed.length) {
      return word.charStates[index] == CharState.correct
          ? AppColors.correct
          : AppColors.incorrect;
    }

    return AppColors.textMuted;
  }
}

class _SpaceWidget extends StatelessWidget {
  final bool showCursor;
  const _SpaceWidget({required this.showCursor});

  @override
  Widget build(BuildContext context) {
    if (!showCursor) return const SizedBox(width: 12);
    final lineHeight =
        AppTheme.monoStyle.fontSize! * (AppTheme.monoStyle.height ?? 1.0);
    return SizedBox(
      width: 12,
      height: lineHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 12,
          height: 2.5,
          color: AppColors.cursor,
        ),
      ),
    );
  }
}
