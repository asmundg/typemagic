/// Test mode types
enum TestMode { sentences }

/// Difficulty tier for word selection
enum DifficultyTier {
  nybegynner(1, 'Nybegynner', 'Vanlige korte ord'),
  laerling(2, 'Lærling', 'Vanlige ord, litt lengre'),
  ordsmith(3, 'Ordsmith', 'Uvanlige ord med æ/ø/å'),
  mester(4, 'Mester', 'Sammensatte ord'),
  trollmann(5, 'Trollmann', 'Fullt ordforråd');

  final int level;
  final String displayName;
  final String description;
  const DifficultyTier(this.level, this.displayName, this.description);
}

/// Configuration for a typing test
class TestConfig {
  final TestMode mode;
  final int value; // seconds for time mode, word count for words/sentences mode
  final DifficultyTier maxTier;
  final bool specialCharFocus; // prefer words with æ/ø/å

  const TestConfig({
    required this.mode,
    required this.value,
    this.maxTier = DifficultyTier.laerling,
    this.specialCharFocus = false,
  });

  static const defaultConfig = TestConfig(mode: TestMode.sentences, value: 3);

  String get label {
    return '$value setn.';
  }

  TestConfig copyWith({
    TestMode? mode,
    int? value,
    DifficultyTier? maxTier,
    bool? specialCharFocus,
  }) {
    return TestConfig(
      mode: mode ?? this.mode,
      value: value ?? this.value,
      maxTier: maxTier ?? this.maxTier,
      specialCharFocus: specialCharFocus ?? this.specialCharFocus,
    );
  }
}

/// State of a single character in the typing test
enum CharState { untyped, correct, incorrect }

/// A word in the test with its typed state
class TestWord {
  final String target;
  final List<CharState> charStates;
  final StringBuffer typed;
  DateTime? startTime;
  DateTime? endTime;

  TestWord(this.target)
      : charStates = List.filled(target.length, CharState.untyped),
        typed = StringBuffer();

  bool get isComplete => typed.length >= target.length;
  bool get isCorrect =>
      typed.toString() == target && !charStates.contains(CharState.incorrect);

  int get correctChars =>
      charStates.where((s) => s == CharState.correct).length;
  int get incorrectChars =>
      charStates.where((s) => s == CharState.incorrect).length;

  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }
}

/// Result of a completed typing test
class TestResult {
  final double wpm;
  final double rawWpm;
  final double accuracy;
  final double consistency;
  final int correctChars;
  final int incorrectChars;
  final int totalChars;
  final int wordCount;
  final Duration duration;
  final TestConfig config;
  final List<WordResult> wordResults;
  final Map<String, KeyStats> keyStats;
  final DateTime completedAt;

  const TestResult({
    required this.wpm,
    required this.rawWpm,
    required this.accuracy,
    required this.consistency,
    required this.correctChars,
    required this.incorrectChars,
    required this.totalChars,
    required this.wordCount,
    required this.duration,
    required this.config,
    required this.wordResults,
    required this.keyStats,
    required this.completedAt,
  });
}

/// Per-word result data
class WordResult {
  final String target;
  final String typed;
  final bool correct;
  final Duration duration;
  final double wpm;

  const WordResult({
    required this.target,
    required this.typed,
    required this.correct,
    required this.duration,
    required this.wpm,
  });
}

/// Per-key accuracy stats
class KeyStats {
  int correct;
  int incorrect;
  int total;

  KeyStats({this.correct = 0, this.incorrect = 0, this.total = 0});

  double get accuracy => total > 0 ? correct / total : 0;
}
