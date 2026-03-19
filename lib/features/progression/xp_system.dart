import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/models.dart';

/// Norwegian-themed level titles with XP thresholds
class LevelInfo {
  final int level;
  final String title;
  final int xpThreshold;
  final DifficultyTier unlockedTier;

  const LevelInfo(this.level, this.title, this.xpThreshold, this.unlockedTier);
}

const _levelMilestones = [
  LevelInfo(1, 'Tastatur-troll', 0, DifficultyTier.nybegynner),
  LevelInfo(5, 'Bokstav-bull', 500, DifficultyTier.laerling),
  LevelInfo(10, 'Ordsmith', 2000, DifficultyTier.ordsmith),
  LevelInfo(20, 'Runemester', 8000, DifficultyTier.mester),
  LevelInfo(35, 'Lynfinger', 25000, DifficultyTier.trollmann),
  LevelInfo(50, 'Stormskriver', 60000, DifficultyTier.trollmann),
  LevelInfo(75, 'Skrivekongen', 150000, DifficultyTier.trollmann),
];

/// Time factor for XP calculation based on test duration in seconds
double _timeFactor(int seconds) {
  if (seconds <= 15) return 0.5;
  if (seconds <= 30) return 0.8;
  if (seconds <= 60) return 1.0;
  if (seconds <= 120) return 1.3;
  return 1.3; // cap at 120s factor
}

/// Calculate XP earned from a test result.
/// Formula: floor(WPM × accuracy² × timeFactor)
/// accuracy is 0-1 (converted from the 0-100 stored in TestResult)
int calculateXP(TestResult result) {
  final accuracy01 = (result.accuracy / 100.0).clamp(0.0, 1.0);
  final seconds = result.duration.inSeconds.clamp(1, 999);
  final tf = _timeFactor(seconds);
  final xp = (result.wpm * accuracy01 * accuracy01 * tf).floor();
  return xp.clamp(0, 99999);
}

/// XP required to reach a given level.
/// Formula: floor(100 × level^1.5)
int xpForLevel(int level) {
  if (level <= 1) return 0;
  return (100 * pow(level, 1.5)).floor();
}

/// Determine the level for a given total XP amount
int levelForXP(int totalXP) {
  int level = 1;
  while (xpForLevel(level + 1) <= totalXP) {
    level++;
  }
  return level;
}

/// Get the title for a given level
String titleForLevel(int level) {
  String title = _levelMilestones.first.title;
  for (final m in _levelMilestones) {
    if (level >= m.level) {
      title = m.title;
    } else {
      break;
    }
  }
  return title;
}

/// Get the highest unlocked difficulty tier for a given level
DifficultyTier tierForLevel(int level) {
  DifficultyTier tier = _levelMilestones.first.unlockedTier;
  for (final m in _levelMilestones) {
    if (level >= m.level) {
      tier = m.unlockedTier;
    } else {
      break;
    }
  }
  return tier;
}

/// Immutable XP / level state
class XPState {
  final int totalXP;
  final int currentLevel;
  final String currentTitle;
  final int xpToNextLevel;
  final double xpProgress;
  final DifficultyTier unlockedTier;

  const XPState({
    this.totalXP = 0,
    this.currentLevel = 1,
    this.currentTitle = 'Tastatur-troll',
    this.xpToNextLevel = 100,
    this.xpProgress = 0.0,
    this.unlockedTier = DifficultyTier.nybegynner,
  });

  factory XPState.fromTotalXP(int totalXP) {
    final level = levelForXP(totalXP);
    final currentThreshold = xpForLevel(level);
    final nextThreshold = xpForLevel(level + 1);
    final range = nextThreshold - currentThreshold;
    final progress = range > 0
        ? ((totalXP - currentThreshold) / range).clamp(0.0, 1.0)
        : 0.0;

    return XPState(
      totalXP: totalXP,
      currentLevel: level,
      currentTitle: titleForLevel(level),
      xpToNextLevel: nextThreshold - totalXP,
      xpProgress: progress,
      unlockedTier: tierForLevel(level),
    );
  }

  /// XP within the current level band (for display in the bar)
  int get xpInCurrentLevel {
    final currentThreshold = xpForLevel(currentLevel);
    return totalXP - currentThreshold;
  }

  /// Total XP needed for the current level band
  int get xpBandSize {
    return xpForLevel(currentLevel + 1) - xpForLevel(currentLevel);
  }
}

const _hiveBoxName = 'xp_data';
const _hiveKeyTotalXP = 'total_xp';

/// Riverpod Notifier that manages XP state with Hive persistence
class XPNotifier extends Notifier<XPState> {
  @override
  XPState build() {
    _loadFromHive();
    return const XPState();
  }

  Future<void> _loadFromHive() async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final totalXP = box.get(_hiveKeyTotalXP, defaultValue: 0) as int;
      state = XPState.fromTotalXP(totalXP);
    } catch (_) {
      // First launch or corrupted data — start fresh
      state = const XPState();
    }
  }

  /// Add XP and persist. Returns the new level if a level-up occurred, else null.
  Future<int?> addXP(int amount) async {
    if (amount <= 0) return null;
    final oldLevel = state.currentLevel;
    final newTotalXP = state.totalXP + amount;

    state = XPState.fromTotalXP(newTotalXP);

    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.put(_hiveKeyTotalXP, newTotalXP);
    } catch (_) {
      // Persistence failed — state is still updated in memory
    }

    return state.currentLevel > oldLevel ? state.currentLevel : null;
  }

  /// Reset all XP data to defaults.
  Future<void> reset() async {
    state = const XPState();
    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.delete(_hiveKeyTotalXP);
    } catch (_) {}
  }

  /// Process a completed test: calculate and add XP.
  /// Returns a record with xpEarned and optional newLevel.
  Future<({int xpEarned, int? newLevel})> processTestResult(
    TestResult result, {
    double multiplier = 1.0,
  }) async {
    final baseXP = calculateXP(result);
    final finalXP = (baseXP * multiplier).floor();
    final newLevel = await addXP(finalXP);
    return (xpEarned: finalXP, newLevel: newLevel);
  }
}

/// Provider for XP state
final xpProvider = NotifierProvider<XPNotifier, XPState>(
  XPNotifier.new,
);
