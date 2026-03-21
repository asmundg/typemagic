import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../core/models.dart';

/// Interpolated trigram Markov chain sentence generator for Norwegian.
///
/// P(w3 | w1, w2) = λ3·P_trigram + λ2·P_bigram + λ1·P_unigram
class SentenceGenerator {
  final Map<String, List<_Transition>> _trigrams;
  final Map<String, List<_Transition>> _bigrams;
  final List<String> _starters; // sentence-starting bigrams ("w1 w2")
  final Map<String, double> _enders; // words that can end a sentence + prob
  final Random _random;

  static const _lambda3 = 0.7;
  static const _lambda2 = 0.2;
  // _lambda1 reserved for unigram smoothing (future enhancement)

  SentenceGenerator._({
    required Map<String, List<_Transition>> trigrams,
    required Map<String, List<_Transition>> bigrams,
    required List<String> starters,
    required Map<String, double> enders,
    Random? random,
  })  : _trigrams = trigrams,
        _bigrams = bigrams,
        _starters = starters,
        _enders = enders,
        _random = random ?? Random();

  /// Generate a sentence with [minWords] to [maxWords] words.
  /// [temperature] controls randomness (0.5 = predictable, 1.2 = creative).
  /// [tierVocab] restricts Markov sampling to words in this set (with fallback).
  String generate({
    int minWords = 5,
    int maxWords = 12,
    double temperature = 0.8,
    Set<String>? tierVocab,
  }) {
    if (_starters.isEmpty) return _fallbackSentence();

    // Try up to 3 candidates, pick the most natural one
    final candidates = <_SentenceCandidate>[];
    for (var attempt = 0; attempt < 3; attempt++) {
      final result = _generateOne(minWords, maxWords, temperature, tierVocab);
      if (result != null) candidates.add(result);
    }

    if (candidates.isEmpty) return _fallbackSentence();

    // Pick highest scoring candidate
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.text;
  }

  _SentenceCandidate? _generateOne(
      int minWords, int maxWords, double temperature, Set<String>? tierVocab) {
    final starter = _starters[_random.nextInt(_starters.length)];
    final parts = starter.split(' ');
    if (parts.length < 2) return null;

    // Store original form for display, use lowercase for lookups
    final words = <String>[parts[0].toLowerCase(), parts[1].toLowerCase()];
    var totalScore = 0.0;

    for (var i = 0; i < maxWords - 2; i++) {
      final w1 = words[words.length - 2];
      final w2 = words[words.length - 1];
      final next = _sampleNext(w1, w2, temperature, tierVocab);

      if (next == null) break;

      // Skip punctuation tokens
      if (next.word == '.' || next.word == ',' || next.word == '!' ||
          next.word == '?') {
        break;
      }

      words.add(next.word);
      totalScore += next.prob;

      // Probabilistic ending: higher-prob enders + longer sentences stop sooner
      final enderProb = _enders[next.word];
      if (words.length >= minWords && enderProb != null) {
        // Linear ramp: at minWords → base chance, at maxWords → certain
        final progress = (words.length - minWords) / (maxWords - minWords);
        final stopChance = enderProb * 10 * (0.3 + 0.7 * progress);
        if (_random.nextDouble() < stopChance) break;
      }
    }

    if (words.length < minWords) return null;
    if (_hasRepetition(words)) return null;
    if (words.any((w) => w.length > 25)) return null;

    // Capitalize first word, add period
    words[0] = _capitalize(words[0]);
    var text = words.join(' ');
    if (!text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?')) {
      text += '.';
    }

    return _SentenceCandidate(
      text: text,
      score: words.length > 2 ? totalScore / (words.length - 2) : 0,
    );
  }

  _Transition? _sampleNext(
      String w1, String w2, double temperature, Set<String>? tierVocab) {
    final triKey = '$w1 $w2';
    final triTransitions = _trigrams[triKey];
    final biTransitions = _bigrams[w2];

    if (triTransitions == null && biTransitions == null) return null;

    // Build interpolated distribution. Out-of-vocabulary words are dampened
    // rather than removed so Markov chains don't dead-end, but in-vocab words
    // are strongly preferred (~20×).
    const outOfVocabDampen = 0.05;
    final combined = <String, double>{};

    if (triTransitions != null) {
      for (final t in triTransitions) {
        final w = (tierVocab != null && !tierVocab.contains(t.word))
            ? outOfVocabDampen
            : 1.0;
        combined[t.word] = (combined[t.word] ?? 0) + _lambda3 * t.prob * w;
      }
    }

    if (biTransitions != null) {
      for (final t in biTransitions) {
        final w = (tierVocab != null && !tierVocab.contains(t.word))
            ? outOfVocabDampen
            : 1.0;
        combined[t.word] = (combined[t.word] ?? 0) + _lambda2 * t.prob * w;
      }
    }

    if (combined.isEmpty) return null;

    // Apply temperature
    final entries = combined.entries.toList();
    final adjusted = entries
        .map((e) => MapEntry(e.key, pow(e.value, 1.0 / temperature).toDouble()))
        .toList();
    final total = adjusted.fold(0.0, (sum, e) => sum + e.value);
    if (total <= 0) return null;

    // Weighted random selection
    var roll = _random.nextDouble() * total;
    for (final entry in adjusted) {
      roll -= entry.value;
      if (roll <= 0) {
        return _Transition(
            entry.key, combined[entry.key]! / total);
      }
    }
    return _Transition(adjusted.last.key, adjusted.last.value / total);
  }

  bool _hasRepetition(List<String> words) {
    final counts = <String, int>{};
    for (final w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
      if (counts[w]! >= 3) return true;
    }
    return false;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _fallbackSentence() {
    const fallbacks = [
      'Det er en fin dag i dag.',
      'Vi går til skolen sammen.',
      'Hun liker å lese bøker.',
      'Han spiser frokost hver morgen.',
      'De bor i et stort hus.',
    ];
    return fallbacks[_random.nextInt(fallbacks.length)];
  }

  /// Load a [SentenceGenerator] from JSON files in [directory].
  ///
  /// Expects `markov_trigrams.json`, `markov_bigrams.json`, and
  /// `markov_meta.json` inside [directory]. Pass [seed] for deterministic
  /// output.
  static SentenceGenerator? loadFromDirectory(String directory, {int? seed}) {
    try {
      final triJson =
          File('$directory/markov_trigrams.json').readAsStringSync();
      final biJson =
          File('$directory/markov_bigrams.json').readAsStringSync();
      final metaJson =
          File('$directory/markov_meta.json').readAsStringSync();

      return _fromJsonStrings(triJson, biJson, metaJson, seed: seed);
    } catch (e) {
      return null;
    }
  }

  /// Build a [SentenceGenerator] from pre-loaded JSON strings.
  static SentenceGenerator? fromJsonStrings(
    String trigramJson,
    String bigramJson,
    String metaJson, {
    int? seed,
  }) =>
      _fromJsonStrings(trigramJson, bigramJson, metaJson, seed: seed);

  static SentenceGenerator? _fromJsonStrings(
    String trigramJson,
    String bigramJson,
    String metaJson, {
    int? seed,
  }) {
    try {
      final triData = json.decode(trigramJson) as Map<String, dynamic>;
      final biData = json.decode(bigramJson) as Map<String, dynamic>;
      final metaData = json.decode(metaJson) as Map<String, dynamic>;

      final trigrams = <String, List<_Transition>>{};
      for (final entry in triData.entries) {
        trigrams[entry.key] = (entry.value as List)
            .map(
                (t) => _Transition(t[0] as String, (t[1] as num).toDouble()))
            .toList();
      }

      final bigrams = <String, List<_Transition>>{};
      for (final entry in biData.entries) {
        bigrams[entry.key] = (entry.value as List)
            .map(
                (t) => _Transition(t[0] as String, (t[1] as num).toDouble()))
            .toList();
      }

      final starters = <String>[];
      for (final s in metaData['starters'] as List) {
        final arr = s as List;
        starters.add('${arr[0]} ${arr[1]}');
      }

      final enders = <String, double>{};
      for (final e in metaData['enders'] as List) {
        final arr = e as List;
        enders[arr[0] as String] = (arr[1] as num).toDouble();
      }

      return SentenceGenerator._(
        trigrams: trigrams,
        bigrams: bigrams,
        starters: starters,
        enders: enders,
        random: seed != null ? Random(seed) : null,
      );
    } catch (e) {
      return null;
    }
  }
}

class _Transition {
  final String word;
  final double prob;
  const _Transition(this.word, this.prob);
}

class _SentenceCandidate {
  final String text;
  final double score;
  const _SentenceCandidate({required this.text, required this.score});
}

/// Configuration for sentence generation per difficulty tier
class TierConfig {
  final double temperature;
  final int minWords;
  final int maxWords;
  const TierConfig(this.temperature, this.minWords, this.maxWords);
}

const tierConfigs = {
  DifficultyTier.nybegynner: TierConfig(0.6, 4, 8),
  DifficultyTier.laerling: TierConfig(0.7, 4, 10),
  DifficultyTier.ordsmith: TierConfig(0.8, 5, 12),
  DifficultyTier.mester: TierConfig(0.9, 6, 15),
  DifficultyTier.trollmann: TierConfig(1.0, 6, 20),
};

/// Generate sentences for a typing test.
/// [tierVocab] constrains word choices to the given vocabulary set.
List<String> generateSentences(
  SentenceGenerator generator, {
  required int count,
  DifficultyTier tier = DifficultyTier.laerling,
  Set<String>? tierVocab,
}) {
  final config = tierConfigs[tier] ?? const TierConfig(0.8, 5, 12);
  return List.generate(
    count,
    (_) => generator.generate(
      minWords: config.minWords,
      maxWords: config.maxWords,
      temperature: config.temperature,
      tierVocab: tierVocab,
    ),
  );
}
