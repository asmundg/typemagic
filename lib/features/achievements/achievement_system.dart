import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/models.dart';
import '../progression/xp_system.dart';

enum AchievementCategory {
  speed('Fart', '🏎'),
  accuracy('Presisjon', '🎯'),
  streaks('Rekker', '🔥'),
  volume('Mengde', '📚'),
  special('Spesielle', '🌙');

  final String displayName;
  final String emoji;
  const AchievementCategory(this.displayName, this.emoji);
}

/// Aggregate stats passed into achievement checks
class StatsAggregates {
  final int totalWordsTyped;
  final int totalTestsCompleted;
  final int consecutiveHighAccuracyTests; // 98%+ streak
  final int currentDayStreak;
  final int uniqueWordsEncountered;
  final bool practicedOnSaturday;
  final bool practicedOnSunday;

  const StatsAggregates({
    this.totalWordsTyped = 0,
    this.totalTestsCompleted = 0,
    this.consecutiveHighAccuracyTests = 0,
    this.currentDayStreak = 0,
    this.uniqueWordsEncountered = 0,
    this.practicedOnSaturday = false,
    this.practicedOnSunday = false,
  });
}

/// A single achievement definition + unlock state
class Achievement {
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? isUnlocked, DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      category: category,
      icon: icon,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// Speed badge tiers, ordered by ascending WPM threshold.
const List<({int wpm, String icon, String name})> speedBadgeTiers = [
  (wpm: 10, icon: '🐌', name: 'Snegle'),
  (wpm: 25, icon: '🏃', name: 'Jogger'),
  (wpm: 40, icon: '💨', name: 'Sprinter'),
  (wpm: 60, icon: '⚡', name: 'Lynet'),
  (wpm: 80, icon: '🚀', name: 'Supersonisk'),
  (wpm: 100, icon: '🛸', name: 'Mach 10'),
];

/// Returns the highest speed badge earned for [wpm], or null if below 10 WPM.
({String icon, String name})? speedBadgeForWpm(double wpm) {
  ({String icon, String name})? best;
  for (final tier in speedBadgeTiers) {
    if (wpm >= tier.wpm) {
      best = (icon: tier.icon, name: tier.name);
    }
  }
  return best;
}

/// All achievement definitions
final List<Achievement> allAchievements = [
  // Speed
  const Achievement(
    id: 'speed_10',
    name: 'Snegle',
    description: 'Nå 10 WPM',
    category: AchievementCategory.speed,
    icon: '🐌',
  ),
  const Achievement(
    id: 'speed_25',
    name: 'Jogger',
    description: 'Nå 25 WPM',
    category: AchievementCategory.speed,
    icon: '🏃',
  ),
  const Achievement(
    id: 'speed_40',
    name: 'Sprinter',
    description: 'Nå 40 WPM',
    category: AchievementCategory.speed,
    icon: '💨',
  ),
  const Achievement(
    id: 'speed_60',
    name: 'Lynet',
    description: 'Nå 60 WPM',
    category: AchievementCategory.speed,
    icon: '⚡',
  ),
  const Achievement(
    id: 'speed_80',
    name: 'Supersonisk',
    description: 'Nå 80 WPM',
    category: AchievementCategory.speed,
    icon: '🚀',
  ),
  const Achievement(
    id: 'speed_100',
    name: 'Mach 10',
    description: 'Nå 100 WPM',
    category: AchievementCategory.speed,
    icon: '🛸',
  ),

  // Accuracy
  const Achievement(
    id: 'acc_95',
    name: 'Skarpskytt',
    description: '95% nøyaktighet i en test',
    category: AchievementCategory.accuracy,
    icon: '🎯',
  ),
  const Achievement(
    id: 'acc_100',
    name: 'Perfeksjonist',
    description: '100% nøyaktighet (25+ ord)',
    category: AchievementCategory.accuracy,
    icon: '💎',
  ),
  const Achievement(
    id: 'acc_streak_10',
    name: 'Feilfri 10',
    description: '10 tester på rad med 98%+ nøyaktighet',
    category: AchievementCategory.accuracy,
    icon: '🏆',
  ),

  // Streaks
  const Achievement(
    id: 'streak_3',
    name: 'Tre på rad',
    description: '3 dager på rad med øving',
    category: AchievementCategory.streaks,
    icon: '🔥',
  ),
  const Achievement(
    id: 'streak_7',
    name: 'Ukentlig',
    description: '7 dager på rad med øving',
    category: AchievementCategory.streaks,
    icon: '📅',
  ),
  const Achievement(
    id: 'streak_30',
    name: 'Månedlig',
    description: '30 dager på rad med øving',
    category: AchievementCategory.streaks,
    icon: '🗓',
  ),
  const Achievement(
    id: 'streak_100',
    name: 'Ustoppelig',
    description: '100 dager på rad med øving',
    category: AchievementCategory.streaks,
    icon: '👑',
  ),

  // Volume
  const Achievement(
    id: 'vol_1',
    name: 'Første ord',
    description: 'Skriv ditt første ord',
    category: AchievementCategory.volume,
    icon: '✏️',
  ),
  const Achievement(
    id: 'vol_1000',
    name: 'Tusen ord',
    description: '1 000 ord totalt',
    category: AchievementCategory.volume,
    icon: '📝',
  ),
  const Achievement(
    id: 'vol_10000',
    name: 'Ti tusen',
    description: '10 000 ord totalt',
    category: AchievementCategory.volume,
    icon: '📖',
  ),
  const Achievement(
    id: 'vol_100000',
    name: 'Hundre tusen',
    description: '100 000 ord totalt',
    category: AchievementCategory.volume,
    icon: '📚',
  ),

  // Special
  const Achievement(
    id: 'special_night',
    name: 'Nattugle',
    description: 'Øv etter kl. 22:00',
    category: AchievementCategory.special,
    icon: '🦉',
  ),
  const Achievement(
    id: 'special_early',
    name: 'Tidlig fugl',
    description: 'Øv før kl. 07:00',
    category: AchievementCategory.special,
    icon: '🐦',
  ),
  const Achievement(
    id: 'special_weekend',
    name: 'Helgekrigeren',
    description: 'Øv både lørdag og søndag i samme helg',
    category: AchievementCategory.special,
    icon: '⚔️',
  ),
  const Achievement(
    id: 'special_aeoa',
    name: 'Æ-Ø-Å Mester',
    description: '100% nøyaktighet med spesialtegn-fokus',
    category: AchievementCategory.special,
    icon: '🇳🇴',
  ),
  const Achievement(
    id: 'special_marathon',
    name: 'Maraton',
    description: 'Fullfør en 120-sekunders test',
    category: AchievementCategory.special,
    icon: '🏅',
  ),
  const Achievement(
    id: 'special_vocab',
    name: 'Ordbok-leser',
    description: 'Møt 1 000 unike ord på tvers av alle tester',
    category: AchievementCategory.special,
    icon: '📕',
  ),
];

/// Checks a test result (+ aggregates) against all achievement criteria.
/// Returns a list of newly unlocked achievement IDs.
class AchievementChecker {
  /// Check all achievements and return IDs of newly unlockable ones
  static List<String> check(
    TestResult result,
    XPState xpState,
    StatsAggregates stats,
    Set<String> alreadyUnlocked,
  ) {
    final newlyUnlocked = <String>[];

    void tryUnlock(String id, bool condition) {
      if (!alreadyUnlocked.contains(id) && condition) {
        newlyUnlocked.add(id);
      }
    }

    // Speed
    tryUnlock('speed_10', result.wpm >= 10);
    tryUnlock('speed_25', result.wpm >= 25);
    tryUnlock('speed_40', result.wpm >= 40);
    tryUnlock('speed_60', result.wpm >= 60);
    tryUnlock('speed_80', result.wpm >= 80);
    tryUnlock('speed_100', result.wpm >= 100);

    // Accuracy
    tryUnlock('acc_95', result.accuracy >= 95.0);
    tryUnlock('acc_100', result.accuracy >= 99.99 && result.wordCount >= 25);
    tryUnlock('acc_streak_10', stats.consecutiveHighAccuracyTests >= 10);

    // Streaks
    tryUnlock('streak_3', stats.currentDayStreak >= 3);
    tryUnlock('streak_7', stats.currentDayStreak >= 7);
    tryUnlock('streak_30', stats.currentDayStreak >= 30);
    tryUnlock('streak_100', stats.currentDayStreak >= 100);

    // Volume
    tryUnlock('vol_1', stats.totalWordsTyped >= 1);
    tryUnlock('vol_1000', stats.totalWordsTyped >= 1000);
    tryUnlock('vol_10000', stats.totalWordsTyped >= 10000);
    tryUnlock('vol_100000', stats.totalWordsTyped >= 100000);

    // Special
    final hour = result.completedAt.hour;
    tryUnlock('special_night', hour >= 22);
    tryUnlock('special_early', hour < 7);
    tryUnlock(
      'special_weekend',
      stats.practicedOnSaturday && stats.practicedOnSunday,
    );
    tryUnlock(
      'special_aeoa',
      result.config.specialCharFocus && result.accuracy >= 99.99,
    );
    tryUnlock(
      'special_marathon',
      result.duration.inSeconds >= 120,
    );
    tryUnlock('special_vocab', stats.uniqueWordsEncountered >= 1000);

    return newlyUnlocked;
  }
}

/// Progress info for partially-completed achievements (for UI display)
class AchievementProgress {
  /// Returns a (current, target) pair for achievements with numeric progress,
  /// or null if the achievement is binary / not trackable.
  static ({int current, int target})? getProgress(
    String achievementId,
    TestResult? latestResult,
    StatsAggregates stats,
  ) {
    return switch (achievementId) {
      // Speed — show best WPM vs target
      'speed_10' => (
          current: latestResult?.wpm.floor() ?? 0,
          target: 10,
        ),
      'speed_25' => (
          current: latestResult?.wpm.floor() ?? 0,
          target: 25,
        ),
      'speed_40' => (
          current: latestResult?.wpm.floor() ?? 0,
          target: 40,
        ),
      'speed_60' => (
          current: latestResult?.wpm.floor() ?? 0,
          target: 60,
        ),
      'speed_80' => (
          current: latestResult?.wpm.floor() ?? 0,
          target: 80,
        ),
      'speed_100' => (
          current: latestResult?.wpm.floor() ?? 0,
          target: 100,
        ),
      // Accuracy streak
      'acc_streak_10' => (
          current: stats.consecutiveHighAccuracyTests,
          target: 10,
        ),
      // Day streaks
      'streak_3' => (current: stats.currentDayStreak, target: 3),
      'streak_7' => (current: stats.currentDayStreak, target: 7),
      'streak_30' => (current: stats.currentDayStreak, target: 30),
      'streak_100' => (current: stats.currentDayStreak, target: 100),
      // Volume
      'vol_1' => (current: stats.totalWordsTyped.clamp(0, 1), target: 1),
      'vol_1000' => (current: stats.totalWordsTyped, target: 1000),
      'vol_10000' => (current: stats.totalWordsTyped, target: 10000),
      'vol_100000' => (current: stats.totalWordsTyped, target: 100000),
      // Vocabulary
      'special_vocab' => (
          current: stats.uniqueWordsEncountered,
          target: 1000,
        ),
      _ => null,
    };
  }
}

const _hiveBoxName = 'achievements';
const _hiveKeyUnlocked = 'unlocked'; // Map<String, int> (id → millis)

class AchievementNotifier extends Notifier<List<Achievement>> {
  @override
  List<Achievement> build() {
    _loadFromHive();
    return List.of(allAchievements);
  }

  Future<void> _loadFromHive() async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final raw = box.get(_hiveKeyUnlocked);
      if (raw != null) {
        final unlocked = Map<String, int>.from(raw as Map);
        state = allAchievements.map((a) {
          final millis = unlocked[a.id];
          if (millis != null) {
            return a.copyWith(
              isUnlocked: true,
              unlockedAt: DateTime.fromMillisecondsSinceEpoch(millis),
            );
          }
          return a;
        }).toList();
      }
    } catch (_) {
      // First launch — use defaults
    }
  }

  Set<String> get _unlockedIds =>
      state.where((a) => a.isUnlocked).map((a) => a.id).toSet();

  /// Check and unlock achievements based on a completed test.
  /// Returns list of newly unlocked achievement names.
  Future<List<String>> checkAndUnlock(
    TestResult result,
    XPState xpState,
    StatsAggregates stats,
  ) async {
    final newIds = AchievementChecker.check(
      result,
      xpState,
      stats,
      _unlockedIds,
    );

    if (newIds.isEmpty) return [];

    final now = DateTime.now();
    final updated = state.map((a) {
      if (newIds.contains(a.id)) {
        return a.copyWith(isUnlocked: true, unlockedAt: now);
      }
      return a;
    }).toList();

    state = updated;

    // Persist
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final unlocked = <String, int>{};
      for (final a in updated.where((a) => a.isUnlocked)) {
        unlocked[a.id] = a.unlockedAt!.millisecondsSinceEpoch;
      }
      await box.put(_hiveKeyUnlocked, unlocked);
    } catch (_) {
      // Persistence failed — state is still updated in memory
    }

    return newIds
        .map((id) => state.firstWhere((a) => a.id == id).name)
        .toList();
  }

  /// Reset all achievements to locked state.
  Future<void> reset() async {
    state = List.of(allAchievements);
    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.delete(_hiveKeyUnlocked);
    } catch (_) {}
  }
}

/// Provider for achievements
final achievementProvider =
    NotifierProvider<AchievementNotifier, List<Achievement>>(
  AchievementNotifier.new,
);
