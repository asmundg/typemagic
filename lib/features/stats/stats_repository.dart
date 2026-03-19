import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/models.dart';

/// Daily aggregate for chart data.
class DailyStats {
  final DateTime date;
  final double avgWpm;
  final double avgAccuracy;
  final int testCount;

  const DailyStats({
    required this.date,
    required this.avgWpm,
    required this.avgAccuracy,
    required this.testCount,
  });
}

/// Summary stats across all tests.
class TotalStats {
  final int totalTests;
  final Duration totalTime;
  final int totalWords;
  final double avgWpm;
  final double avgAccuracy;

  const TotalStats({
    required this.totalTests,
    required this.totalTime,
    required this.totalWords,
    required this.avgWpm,
    required this.avgAccuracy,
  });
}

/// Hive-based persistence for test results.
class StatsRepository {
  static const _boxName = 'test_results';

  Box get _box => Hive.box(_boxName);

  /// Save a completed test result.
  void saveResult(TestResult result) {
    _box.add(_resultToJson(result));
  }

  /// Clear all stored test results.
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// Get test history, optionally filtered by mode and limited.
  List<TestResult> getHistory({int? limit, TestMode? mode}) {
    final results = <TestResult>[];
    for (final value in _box.values) {
      try {
        final result = _resultFromJson(value as Map);
        if (mode == null || result.config.mode == mode) {
          results.add(result);
        }
      } catch (_) {
        // Skip malformed entries
      }
    }

    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Get personal best WPM per test mode.
  Map<TestMode, double> getPersonalBests() {
    final bests = <TestMode, double>{};
    for (final value in _box.values) {
      try {
        final result = _resultFromJson(value as Map);
        final mode = result.config.mode;
        if (!bests.containsKey(mode) || result.wpm > bests[mode]!) {
          bests[mode] = result.wpm;
        }
      } catch (_) {
        // Skip malformed entries
      }
    }
    return bests;
  }

  /// Aggregate per-key accuracy across all tests.
  Map<String, KeyStats> getKeyStatsAggregate() {
    final aggregate = <String, KeyStats>{};
    for (final value in _box.values) {
      try {
        final result = _resultFromJson(value as Map);
        for (final entry in result.keyStats.entries) {
          aggregate.putIfAbsent(entry.key, () => KeyStats());
          aggregate[entry.key]!.correct += entry.value.correct;
          aggregate[entry.key]!.incorrect += entry.value.incorrect;
          aggregate[entry.key]!.total += entry.value.total;
        }
      } catch (_) {
        // Skip malformed entries
      }
    }
    return aggregate;
  }

  /// Get daily aggregates for chart data.
  /// Pass [days] to limit to the last N days, or null for all time.
  List<DailyStats> getDailyStats({int? days}) {
    final cutoff = days != null
        ? DateTime.now().subtract(Duration(days: days))
        : DateTime(1970);

    final byDay = <String, List<TestResult>>{};
    for (final value in _box.values) {
      try {
        final result = _resultFromJson(value as Map);
        if (result.completedAt.isAfter(cutoff)) {
          final d = result.completedAt;
          final dayKey =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          byDay.putIfAbsent(dayKey, () => []);
          byDay[dayKey]!.add(result);
        }
      } catch (_) {
        // Skip malformed entries
      }
    }

    final stats = byDay.entries.map((entry) {
      final dayResults = entry.value;
      final avgWpm =
          dayResults.map((r) => r.wpm).reduce((a, b) => a + b) /
              dayResults.length;
      final avgAccuracy =
          dayResults.map((r) => r.accuracy).reduce((a, b) => a + b) /
              dayResults.length;
      return DailyStats(
        date: DateTime.parse(entry.key),
        avgWpm: avgWpm,
        avgAccuracy: avgAccuracy,
        testCount: dayResults.length,
      );
    }).toList();

    stats.sort((a, b) => a.date.compareTo(b.date));
    return stats;
  }

  /// Get totals across all tests.
  TotalStats getTotalStats() {
    if (_box.isEmpty) {
      return const TotalStats(
        totalTests: 0,
        totalTime: Duration.zero,
        totalWords: 0,
        avgWpm: 0,
        avgAccuracy: 0,
      );
    }

    int totalTests = 0;
    int totalMs = 0;
    int totalWords = 0;
    double sumWpm = 0;
    double sumAccuracy = 0;

    for (final value in _box.values) {
      try {
        final result = _resultFromJson(value as Map);
        totalTests++;
        totalMs += result.duration.inMilliseconds;
        totalWords += result.wordCount;
        sumWpm += result.wpm;
        sumAccuracy += result.accuracy;
      } catch (_) {
        // Skip malformed entries
      }
    }

    return TotalStats(
      totalTests: totalTests,
      totalTime: Duration(milliseconds: totalMs),
      totalWords: totalWords,
      avgWpm: totalTests > 0 ? sumWpm / totalTests : 0,
      avgAccuracy: totalTests > 0 ? sumAccuracy / totalTests : 0,
    );
  }

  // --- Serialization ---

  static Map<String, dynamic> _resultToJson(TestResult result) {
    return {
      'wpm': result.wpm,
      'rawWpm': result.rawWpm,
      'accuracy': result.accuracy,
      'consistency': result.consistency,
      'correctChars': result.correctChars,
      'incorrectChars': result.incorrectChars,
      'totalChars': result.totalChars,
      'wordCount': result.wordCount,
      'durationMs': result.duration.inMilliseconds,
      'config': {
        'mode': result.config.mode.index,
        'value': result.config.value,
        'maxTier': result.config.maxTier.index,
        'specialCharFocus': result.config.specialCharFocus,
      },
      'wordResults': result.wordResults
          .map((wr) => {
                'target': wr.target,
                'typed': wr.typed,
                'correct': wr.correct,
                'durationMs': wr.duration.inMilliseconds,
                'wpm': wr.wpm,
              })
          .toList(),
      'keyStats': result.keyStats.map((key, stats) => MapEntry(key, {
            'correct': stats.correct,
            'incorrect': stats.incorrect,
            'total': stats.total,
          })),
      'completedAt': result.completedAt.toIso8601String(),
    };
  }

  static TestResult _resultFromJson(Map<dynamic, dynamic> json) {
    final configMap = json['config'] as Map;
    return TestResult(
      wpm: (json['wpm'] as num).toDouble(),
      rawWpm: (json['rawWpm'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      consistency: (json['consistency'] as num).toDouble(),
      correctChars: json['correctChars'] as int,
      incorrectChars: json['incorrectChars'] as int,
      totalChars: json['totalChars'] as int,
      wordCount: json['wordCount'] as int,
      duration: Duration(milliseconds: json['durationMs'] as int),
      config: TestConfig(
        mode: TestMode.values[configMap['mode'] as int],
        value: configMap['value'] as int,
        maxTier: DifficultyTier.values[configMap['maxTier'] as int],
        specialCharFocus: configMap['specialCharFocus'] as bool,
      ),
      wordResults: (json['wordResults'] as List).map((wr) {
        final wrMap = wr as Map;
        return WordResult(
          target: wrMap['target'] as String,
          typed: wrMap['typed'] as String,
          correct: wrMap['correct'] as bool,
          duration: Duration(milliseconds: wrMap['durationMs'] as int),
          wpm: (wrMap['wpm'] as num).toDouble(),
        );
      }).toList(),
      keyStats: (json['keyStats'] as Map).map((key, stats) {
        final statsMap = stats as Map;
        return MapEntry(
          key as String,
          KeyStats(
            correct: statsMap['correct'] as int,
            incorrect: statsMap['incorrect'] as int,
            total: statsMap['total'] as int,
          ),
        );
      }),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}

/// Provider for the stats repository.
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository();
});
