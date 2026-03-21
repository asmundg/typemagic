import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/models.dart';
import '../dictionary/word_provider.dart';

/// Deterministic seed from a date (year × 10000 + month × 100 + day)
int _dateSeed(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

/// Generate the daily word list using a date-seeded RNG
List<String> generateDailyWords(
  DateTime date,
  WordProvider wordProvider,
  DifficultyTier maxTier,
) {
  const wordCount = 25;
  final seed = _dateSeed(date);
  final rng = Random(seed);

  // Build the full pool up to the player's unlocked tier
  final pool = <String>[];
  for (final tier in DifficultyTier.values) {
    if (tier.level > maxTier.level) break;
    final tierWords =
        wordProvider.getWords(200, maxTier: tier, specialCharFocus: false);
    pool.addAll(tierWords);
  }

  if (pool.isEmpty) {
    return wordProvider.getWords(wordCount, maxTier: maxTier);
  }

  // Deduplicate and select deterministically
  final unique = pool.toSet().toList()..sort();
  final selected = <String>[];
  for (var i = 0; i < wordCount; i++) {
    selected.add(unique[rng.nextInt(unique.length)]);
  }
  return selected;
}

class DailyChallengeState {
  final List<String> todaysWords;
  final bool isCompleted;
  final int currentStreak;
  final int bestStreak;
  final String dateKey; // "YYYY-MM-DD" of today's challenge

  const DailyChallengeState({
    this.todaysWords = const [],
    this.isCompleted = false,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.dateKey = '',
  });

  DailyChallengeState copyWith({
    List<String>? todaysWords,
    bool? isCompleted,
    int? currentStreak,
    int? bestStreak,
    String? dateKey,
  }) {
    return DailyChallengeState(
      todaysWords: todaysWords ?? this.todaysWords,
      isCompleted: isCompleted ?? this.isCompleted,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      dateKey: dateKey ?? this.dateKey,
    );
  }

  /// XP multiplier for the daily challenge
  static const double xpMultiplier = 1.5;
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _dateToKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _hiveBoxName = 'daily_challenge';

class DailyChallengeNotifier extends Notifier<DailyChallengeState> {
  @override
  DailyChallengeState build() {
    _loadFromHive();
    return const DailyChallengeState();
  }

  Future<void> _loadFromHive() async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final savedDateKey = box.get('date_key', defaultValue: '') as String;
      final currentStreak = box.get('current_streak', defaultValue: 0) as int;
      final bestStreak = box.get('best_streak', defaultValue: 0) as int;
      final todayStr = _todayKey();

      bool isCompleted = false;
      if (savedDateKey == todayStr) {
        isCompleted = box.get('is_completed', defaultValue: false) as bool;
      } else {
        // New day — check if streak is intact (played yesterday)
        final yesterdayKey =
            _dateToKey(DateTime.now().subtract(const Duration(days: 1)));
        final lastCompletedKey =
            box.get('last_completed_key', defaultValue: '') as String;
        final streakAlive = lastCompletedKey == yesterdayKey;
        if (!streakAlive && lastCompletedKey != todayStr) {
          // Streak broken — reset
          await box.put('current_streak', 0);
        }
      }

      final words = _generateWords();

      state = DailyChallengeState(
        todaysWords: words,
        isCompleted: isCompleted,
        currentStreak:
            isCompleted ? currentStreak : box.get('current_streak', defaultValue: 0) as int,
        bestStreak: bestStreak,
        dateKey: todayStr,
      );
    } catch (_) {
      state = DailyChallengeState(
        todaysWords: _generateWords(),
        dateKey: _todayKey(),
      );
    }
  }

  List<String> _generateWords() {
    final wp = ref.read(wordProviderFutureProvider);
    if (wp.value == null) return const [];
    return generateDailyWords(
      DateTime.now(),
      wp.value!,
      DifficultyTier.laerling, // default tier for daily
    );
  }

  /// Regenerate words using a specific tier (call after XP state is loaded)
  void refreshWords(DifficultyTier maxTier) {
    final wp = ref.read(wordProviderFutureProvider);
    if (wp.value == null) return;
    final words = generateDailyWords(DateTime.now(), wp.value!, maxTier);
    state = state.copyWith(todaysWords: words);
  }

  /// Mark today's daily challenge as completed and update streak
  Future<void> completeDaily() async {
    if (state.isCompleted) return;

    final todayStr = _todayKey();
    final newStreak = state.currentStreak + 1;
    final newBest =
        newStreak > state.bestStreak ? newStreak : state.bestStreak;

    state = state.copyWith(
      isCompleted: true,
      currentStreak: newStreak,
      bestStreak: newBest,
      dateKey: todayStr,
    );

    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.put('date_key', todayStr);
      await box.put('is_completed', true);
      await box.put('current_streak', newStreak);
      await box.put('best_streak', newBest);
      await box.put('last_completed_key', todayStr);
    } catch (_) {
      // Persistence failed — state is still updated in memory
    }
  }

  /// Record that the user practiced today (any test completion).
  /// Increments the streak if this is the first practice of the day.
  Future<void> recordPracticeDay() async {
    final todayStr = _todayKey();

    // Already recorded today — nothing to do
    if (state.dateKey == todayStr && state.isCompleted) return;

    final box = await Hive.openBox(_hiveBoxName);
    final lastCompletedKey =
        box.get('last_completed_key', defaultValue: '') as String;

    // Already recorded today via Hive (handles app restart within same day)
    if (lastCompletedKey == todayStr) return;

    final yesterdayKey =
        _dateToKey(DateTime.now().subtract(const Duration(days: 1)));
    final streakAlive = lastCompletedKey == yesterdayKey;
    final baseStreak = streakAlive ? state.currentStreak : 0;
    final newStreak = baseStreak + 1;
    final newBest =
        newStreak > state.bestStreak ? newStreak : state.bestStreak;

    state = state.copyWith(
      isCompleted: true,
      currentStreak: newStreak,
      bestStreak: newBest,
      dateKey: todayStr,
    );

    try {
      await box.put('date_key', todayStr);
      await box.put('is_completed', true);
      await box.put('current_streak', newStreak);
      await box.put('best_streak', newBest);
      await box.put('last_completed_key', todayStr);
    } catch (_) {
      // Persistence failed — state is still updated in memory
    }
  }

  /// Check if the daily challenge has words ready
  bool get hasWords => state.todaysWords.isNotEmpty;

  /// Build a TestConfig for the daily challenge
  TestConfig get dailyConfig => const TestConfig(
        mode: TestMode.sentences,
        value: 3,
        maxTier: DifficultyTier.laerling,
      );
}

/// Provider for daily challenge state
final dailyChallengeProvider =
    NotifierProvider<DailyChallengeNotifier, DailyChallengeState>(
  DailyChallengeNotifier.new,
);
