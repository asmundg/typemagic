import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/models.dart';
import 'typing_test_state.dart';
import 'results_screen.dart';
import '../../widgets/test_config_bar.dart';
import '../../widgets/xp_bar.dart';
import '../../widgets/confetti_overlay.dart';

class TypingTestScreen extends ConsumerStatefulWidget {
  const TypingTestScreen({super.key});

  @override
  ConsumerState<TypingTestScreen> createState() => _TypingTestScreenState();
}

class _TypingTestScreenState extends ConsumerState<TypingTestScreen>
    with TickerProviderStateMixin {
  final _focusNode = FocusNode();

  // Finish animation state
  AnimationController? _summaryController;
  Animation<double>? _summarySlide;
  Animation<double>? _summaryFade;
  bool _showConfetti = false;
  bool _showFullResults = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _summaryController?.dispose();
    super.dispose();
  }

  void _triggerFinishAnimation() {
    _summaryController?.dispose();
    _summaryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _summarySlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _summaryController!, curve: Curves.easeOutCubic),
    );
    _summaryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _summaryController!,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );
    setState(() {
      _showConfetti = true;
      _showFullResults = false;
    });
    _summaryController!.forward();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    final notifier = ref.read(typingTestProvider.notifier);
    final state = ref.read(typingTestProvider);

    // Tab to restart
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _resetAnimations();
      notifier.restart();
      return KeyEventResult.handled;
    }

    // Escape to reset
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _resetAnimations();
      notifier.restart();
      return KeyEventResult.handled;
    }

    if (state.phase == TypingPhase.finished) {
      // Enter or space on finished → show full results
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        setState(() => _showFullResults = true);
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

  void _resetAnimations() {
    _summaryController?.dispose();
    _summaryController = null;
    _showConfetti = false;
    _showFullResults = false;
  }

  @override
  Widget build(BuildContext context) {
    final testState = ref.watch(typingTestProvider);

    // Trigger finish animation when phase transitions to finished
    if (testState.phase == TypingPhase.finished &&
        testState.result != null &&
        _summaryController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerFinishAnimation();
      });
    }

    // Full results screen (after pressing enter/space or tapping "detaljer")
    if (_showFullResults && testState.result != null) {
      return ResultsScreen(
        result: testState.result!,
        onRestart: () {
          _resetAnimations();
          ref.read(typingTestProvider.notifier).restart();
        },
        onRetry: () {
          _resetAnimations();
          ref.read(typingTestProvider.notifier).retry();
        },
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Stack(
          children: [
            // Main typing content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const XPBar(),
                      const SizedBox(height: 16),
                      TestConfigBar(
                        config: testState.config,
                        onConfigChanged: (config) =>
                            ref.read(typingTestProvider.notifier).setConfig(config),
                      ),
                      const SizedBox(height: 24),
                      _LiveStatsBar(state: testState),
                      const SizedBox(height: 32),
                      _WordsDisplay(state: testState),
                      const SizedBox(height: 48),

                      // Hint text or summary panel
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
                      if (testState.phase == TypingPhase.finished &&
                          testState.result != null &&
                          _summaryController != null)
                        AnimatedBuilder(
                          animation: _summaryController!,
                          builder: (context, _) => _SummaryPanel(
                            result: testState.result!,
                            slideOffset: _summarySlide?.value ?? 0,
                            opacity: _summaryFade?.value ?? 0,
                            onRestart: () {
                              _resetAnimations();
                              ref.read(typingTestProvider.notifier).restart();
                            },
                            onRetry: () {
                              _resetAnimations();
                              ref.read(typingTestProvider.notifier).retry();
                            },
                            onDetails: () =>
                                setState(() => _showFullResults = true),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Confetti overlay
            if (_showConfetti)
              Positioned.fill(
                child: ConfettiOverlay(
                  onComplete: () => setState(() => _showConfetti = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary panel shown inline after finishing
// ---------------------------------------------------------------------------

class _SummaryPanel extends StatelessWidget {
  final TestResult result;
  final double slideOffset;
  final double opacity;
  final VoidCallback onRestart;
  final VoidCallback onRetry;
  final VoidCallback onDetails;

  const _SummaryPanel({
    required this.result,
    required this.slideOffset,
    required this.opacity,
    required this.onRestart,
    required this.onRetry,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, slideOffset),
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main stats row
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
                  _SummaryBigStat(
                    value: '${result.wpm.round()}',
                    label: 'wpm',
                    color: AppColors.speedLine,
                  ),
                  const SizedBox(width: 48),
                  _SummaryBigStat(
                    value: '${result.accuracy.round()}%',
                    label: 'nøyaktighet',
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 48),
                  _SummaryBigStat(
                    value: _formatDuration(result.duration),
                    label: 'tid',
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SummaryButton(
                  label: 'prøv igjen',
                  icon: Icons.replay,
                  onTap: onRetry,
                ),
                const SizedBox(width: 10),
                _SummaryButton(
                  label: 'nye setninger',
                  icon: Icons.refresh,
                  onTap: onRestart,
                  primary: true,
                ),
                const SizedBox(width: 10),
                _SummaryButton(
                  label: 'detaljer',
                  icon: Icons.bar_chart,
                  onTap: onDetails,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'tab nye setninger  •  enter detaljer',
              style: AppTheme.monoStyleSmall.copyWith(
                color: AppColors.textSubtle,
                fontSize: 12,
              ),
            ),
          ],
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

class _SummaryBigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryBigStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SummaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _SummaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: primary ? AppColors.background : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.monoStyleSmall.copyWith(
                  color: primary ? AppColors.background : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live stats bar
// ---------------------------------------------------------------------------

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
          const SizedBox(width: 24),
          _StatChip(
            label: '${state.currentWordIndex}',
            suffix: '/${state.words.length}',
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String? suffix;
  final Color color;

  const _StatChip({
    required this.label,
    this.suffix,
    required this.color,
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
            fontSize: 20,
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
