import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../dictionary/word_provider.dart';
import '../sentence_gen/sentence_generator.dart';
import '../stats/stats_repository.dart';
import '../progression/xp_system.dart';
import '../progression/daily_challenge.dart';
import '../achievements/achievement_system.dart';

/// Possible states of the typing test
enum TypingPhase { waiting, running, finished }

/// The full state of an active typing test
class TypingTestState {
  final TypingPhase phase;
  final TestConfig config;
  final List<TestWord> words;
  final int currentWordIndex;
  final int timeLeft;
  final int elapsedMs;
  final double liveWpm;
  final double liveAccuracy;
  final TestResult? result;
  final List<Achievement> newlyUnlocked;

  const TypingTestState({
    this.phase = TypingPhase.waiting,
    this.config = TestConfig.defaultConfig,
    this.words = const [],
    this.currentWordIndex = 0,
    this.timeLeft = 0,
    this.elapsedMs = 0,
    this.liveWpm = 0,
    this.liveAccuracy = 100,
    this.result,
    this.newlyUnlocked = const [],
  });

  TestWord? get currentWord =>
      currentWordIndex < words.length ? words[currentWordIndex] : null;

  bool get isLastWord => currentWordIndex >= words.length - 1;

  TypingTestState copyWith({
    TypingPhase? phase,
    TestConfig? config,
    List<TestWord>? words,
    int? currentWordIndex,
    int? timeLeft,
    int? elapsedMs,
    double? liveWpm,
    double? liveAccuracy,
    TestResult? result,
    List<Achievement>? newlyUnlocked,
  }) {
    return TypingTestState(
      phase: phase ?? this.phase,
      config: config ?? this.config,
      words: words ?? this.words,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      timeLeft: timeLeft ?? this.timeLeft,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      liveWpm: liveWpm ?? this.liveWpm,
      liveAccuracy: liveAccuracy ?? this.liveAccuracy,
      result: result ?? this.result,
      newlyUnlocked: newlyUnlocked ?? this.newlyUnlocked,
    );
  }
}

/// Core typing test logic using modern Riverpod Notifier
class TypingTestNotifier extends Notifier<TypingTestState> {
  Timer? _timer;
  DateTime? _testStartTime;
  final Map<String, KeyStats> _keyStats = {};

  WordProvider get _wordProvider {
    final wp = ref.read(wordProviderFutureProvider);
    return wp.value ?? WordProvider(const {}, const ['laster']);
  }

  SentenceGenerator? get _sentenceGenerator {
    final sg = ref.read(sentenceGeneratorProvider);
    return sg.value;
  }

  @override
  TypingTestState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    // Watch the word provider so we rebuild once it loads
    ref.watch(wordProviderFutureProvider);
    return _createInitialState(TestConfig.defaultConfig);
  }

  TypingTestState _createInitialState(TestConfig config) {
    List<String> wordStrings;

    final gen = _sentenceGenerator;
    if (gen != null) {
      final tierVocab = _wordProvider.getVocabularySet(config.maxTier);
      final sentences = generateSentences(
        gen,
        count: config.value,
        tier: config.maxTier,
        tierVocab: tierVocab.isNotEmpty ? tierVocab : null,
      );
      // Split sentences into individual words
      wordStrings = sentences
          .expand((s) => s.split(' '))
          .where((w) => w.isNotEmpty)
          .toList();
    } else {
      // Fallback to random words if no Markov model
      wordStrings = _wordProvider.getWords(config.value * 8,
          maxTier: config.maxTier,
          specialCharFocus: config.specialCharFocus);
    }

    return TypingTestState(
      phase: TypingPhase.waiting,
      config: config,
      words: wordStrings.map((w) => TestWord(w)).toList(),
    );
  }

  void setConfig(TestConfig config) {
    _stopTimer();
    _keyStats.clear();
    state = _createInitialState(config);
  }

  void restart() {
    _stopTimer();
    _keyStats.clear();
    state = _createInitialState(state.config);
  }

  /// Start a drill with pre-generated words.
  void startDrill(List<String> words) {
    _stopTimer();
    _keyStats.clear();
    final config = TestConfig(mode: TestMode.drill, value: words.length);
    state = TypingTestState(
      phase: TypingPhase.waiting,
      config: config,
      words: words.map((w) => TestWord(w)).toList(),
    );
  }

  void retry() {
    _stopTimer();
    _keyStats.clear();
    final words = state.words.map((w) => TestWord(w.target)).toList();
    state = TypingTestState(
      phase: TypingPhase.waiting,
      config: state.config,
      words: words,
    );
  }

  void onChar(String char) {
    if (state.phase == TypingPhase.finished) return;
    if (state.phase == TypingPhase.waiting) _startTest();

    final word = state.currentWord;
    if (word == null) return;

    word.startTime ??= DateTime.now();
    final pos = word.typed.length;
    word.typed.write(char);

    final key = char.toLowerCase();
    _keyStats.putIfAbsent(key, () => KeyStats());
    _keyStats[key]!.total++;

    if (pos < word.target.length) {
      if (word.target[pos] == char) {
        word.charStates[pos] = CharState.correct;
        _keyStats[key]!.correct++;
      } else {
        word.charStates[pos] = CharState.incorrect;
        _keyStats[key]!.incorrect++;
      }
    }

    _updateLiveStats();
    state = state.copyWith(words: List.of(state.words));

    // Auto-finish when last character of last word is typed
    if (state.isLastWord && word.isComplete) {
      word.endTime = DateTime.now();
      if (!word.isCorrect) {
        _wordProvider.recordWeakWord(word.target);
      }
      _finishTest();
    }
  }

  void onBackspace() {
    if (state.phase != TypingPhase.running) return;

    final word = state.currentWord;
    if (word == null) return;

    if (word.typed.isEmpty) {
      // Backspace at start of word → go back to previous word
      if (state.currentWordIndex > 0) {
        final prevIndex = state.currentWordIndex - 1;
        final prevWord = state.words[prevIndex];
        prevWord.endTime = null;
        state = state.copyWith(currentWordIndex: prevIndex);
      }
      return;
    }

    final pos = word.typed.length - 1;
    final current = word.typed.toString();
    word.typed.clear();
    word.typed.write(current.substring(0, pos));

    if (pos < word.target.length) {
      word.charStates[pos] = CharState.untyped;
    }

    _updateLiveStats();
    state = state.copyWith(words: List.of(state.words));
  }

  void onSpace() {
    if (state.phase != TypingPhase.running) return;

    final word = state.currentWord;
    if (word == null || word.typed.isEmpty) return;

    word.endTime = DateTime.now();

    // Track weak words (incorrect ones)
    if (!word.isCorrect) {
      _wordProvider.recordWeakWord(word.target);
    }

    final nextIndex = state.currentWordIndex + 1;

    if (nextIndex >= state.words.length) {
      _finishTest();
      return;
    }

    state = state.copyWith(currentWordIndex: nextIndex);
    _updateLiveStats();
  }

  void _startTest() {
    _testStartTime = DateTime.now();
    state = state.copyWith(phase: TypingPhase.running);

    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final elapsed =
          DateTime.now().difference(_testStartTime!).inMilliseconds;
      state = state.copyWith(elapsedMs: elapsed);
      _updateLiveStats();
    });
  }

  void _updateLiveStats() {
    if (_testStartTime == null) return;

    final elapsed = DateTime.now().difference(_testStartTime!).inMilliseconds;
    if (elapsed < 500) return;

    int totalCorrect = 0;
    int totalTyped = 0;
    for (var i = 0; i <= state.currentWordIndex && i < state.words.length; i++) {
      final w = state.words[i];
      totalCorrect += w.correctChars;
      totalTyped += w.typed.length;
      if (i < state.currentWordIndex) {
        totalCorrect++;
        totalTyped++;
      }
    }

    final minutes = elapsed / 60000.0;
    final wpm = minutes > 0 ? (totalCorrect / 5.0) / minutes : 0.0;
    final accuracy =
        totalTyped > 0 ? (totalCorrect / totalTyped.toDouble()) * 100.0 : 100.0;

    state = state.copyWith(
      liveWpm: wpm,
      liveAccuracy: accuracy,
      elapsedMs: elapsed,
    );
  }

  Future<void> _finishTest() async {
    _stopTimer();

    final duration = _testStartTime != null
        ? DateTime.now().difference(_testStartTime!)
        : Duration.zero;

    int totalCorrect = 0;
    int totalIncorrect = 0;
    int totalChars = 0;
    final wordResults = <WordResult>[];
    final wordWpms = <double>[];

    final completedCount = state.currentWordIndex + 1;

    for (var i = 0; i < completedCount && i < state.words.length; i++) {
      final w = state.words[i];
      w.endTime ??= DateTime.now();
      totalCorrect += w.correctChars;
      totalIncorrect += w.incorrectChars;
      totalChars += w.typed.length;

      final wd = w.duration ?? const Duration(milliseconds: 500);
      final wordMinutes = wd.inMilliseconds / 60000.0;
      final wordWpm =
          wordMinutes > 0 ? (w.target.length / 5.0) / wordMinutes : 0.0;
      wordWpms.add(wordWpm);

      wordResults.add(WordResult(
        target: w.target,
        typed: w.typed.toString(),
        correct: w.isCorrect,
        duration: wd,
        wpm: wordWpm,
      ));
    }

    totalCorrect += (completedCount - 1).clamp(0, 999);
    totalChars += (completedCount - 1).clamp(0, 999);

    final minutes = duration.inMilliseconds / 60000.0;
    final wpm = minutes > 0 ? (totalCorrect / 5.0) / minutes : 0.0;
    final rawWpm = minutes > 0 ? (totalChars / 5.0) / minutes : 0.0;
    final accuracy =
        totalChars > 0 ? (totalCorrect / totalChars.toDouble()) * 100.0 : 100.0;

    double consistency = 100.0;
    if (wordWpms.length > 1) {
      final mean = wordWpms.reduce((a, b) => a + b) / wordWpms.length;
      final variance =
          wordWpms.map((w) => (w - mean) * (w - mean)).reduce((a, b) => a + b) /
              wordWpms.length;
      final stdDev = sqrt(variance);
      final cv = mean > 0 ? (stdDev / mean) * 100.0 : 0.0;
      consistency = (100.0 - cv).clamp(0.0, 100.0);
    }

    final result = TestResult(
      wpm: wpm,
      rawWpm: rawWpm,
      accuracy: accuracy.clamp(0.0, 100.0),
      consistency: consistency,
      correctChars: totalCorrect,
      incorrectChars: totalIncorrect,
      totalChars: totalChars,
      wordCount: completedCount,
      duration: duration,
      config: state.config,
      wordResults: wordResults,
      keyStats: Map.from(_keyStats),
      completedAt: DateTime.now(),
    );

    state = state.copyWith(
      phase: TypingPhase.finished,
      result: result,
    );

    // Persist the result
    try {
      ref.read(statsRepositoryProvider).saveResult(result);
    } catch (_) {
      // Don't crash the app if persistence fails
    }

    // Skip XP, streaks, and achievements for drill mode
    if (state.config.mode != TestMode.drill) {
      // Award XP
      try {
        final xp = calculateXP(result);
        ref.read(xpProvider.notifier).addXP(xp);
      } catch (_) {}

      // Record practice day for streak tracking
      try {
        ref.read(dailyChallengeProvider.notifier).recordPracticeDay();
      } catch (_) {}

      // Check achievements
      try {
        final xpState = ref.read(xpProvider);
        final totalStats = ref.read(statsRepositoryProvider).getTotalStats();
        final statsAgg = StatsAggregates(
          totalWordsTyped: totalStats.totalWords,
          totalTestsCompleted: totalStats.totalTests,
        );
        final newNames = await ref.read(achievementProvider.notifier).checkAndUnlock(
              result,
              xpState,
              statsAgg,
            );
        if (newNames.isNotEmpty) {
          final achievements = ref.read(achievementProvider);
          final unlocked = achievements
              .where((a) => newNames.contains(a.name))
              .toList();
          state = state.copyWith(newlyUnlocked: unlocked);
        }
      } catch (_) {}
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provider for the typing test state
final typingTestProvider =
    NotifierProvider<TypingTestNotifier, TypingTestState>(
  TypingTestNotifier.new,
);
