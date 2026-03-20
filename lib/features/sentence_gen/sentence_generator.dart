import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';

/// Interpolated trigram Markov chain sentence generator for Norwegian.
///
/// P(w3 | w1, w2) = λ3·P_trigram + λ2·P_bigram + λ1·P_unigram
class SentenceGenerator {
  final Map<String, List<_Transition>> _trigrams;
  final Map<String, List<_Transition>> _bigrams;
  final List<String> _starters; // sentence-starting bigrams ("w1 w2")
  final Set<String> _enders; // words that can end a sentence
  final Random _random;

  static const _lambda3 = 0.7;
  static const _lambda2 = 0.2;
  // _lambda1 reserved for unigram smoothing (future enhancement)

  SentenceGenerator._({
    required Map<String, List<_Transition>> trigrams,
    required Map<String, List<_Transition>> bigrams,
    required List<String> starters,
    required Set<String> enders,
  })  : _trigrams = trigrams,
        _bigrams = bigrams,
        _starters = starters,
        _enders = enders,
        _random = Random();

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

      // Can stop at a natural ending after minWords
      if (words.length >= minWords && _enders.contains(next.word)) break;
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
class _TierConfig {
  final double temperature;
  final int minWords;
  final int maxWords;
  const _TierConfig(this.temperature, this.minWords, this.maxWords);
}

const _tierConfigs = {
  DifficultyTier.nybegynner: _TierConfig(0.6, 4, 8),
  DifficultyTier.laerling: _TierConfig(0.7, 4, 10),
  DifficultyTier.ordsmith: _TierConfig(0.8, 5, 12),
  DifficultyTier.mester: _TierConfig(0.9, 6, 15),
  DifficultyTier.trollmann: _TierConfig(1.0, 6, 20),
};

/// Provides a SentenceGenerator loaded from bundled Markov model assets
final sentenceGeneratorProvider =
    FutureProvider<SentenceGenerator?>((ref) async {
  try {
    final triJson =
        await rootBundle.loadString('assets/markov/markov_trigrams.json');
    final biJson =
        await rootBundle.loadString('assets/markov/markov_bigrams.json');
    final metaJson =
        await rootBundle.loadString('assets/markov/markov_meta.json');

    final triData = json.decode(triJson) as Map<String, dynamic>;
    final biData = json.decode(biJson) as Map<String, dynamic>;
    final metaData = json.decode(metaJson) as Map<String, dynamic>;

    // Parse trigrams: {"w1 w2": [["w3", prob], ...]}
    final trigrams = <String, List<_Transition>>{};
    for (final entry in triData.entries) {
      trigrams[entry.key] = (entry.value as List)
          .map((t) => _Transition(t[0] as String, (t[1] as num).toDouble()))
          .toList();
    }

    // Parse bigrams: {"w1": [["w2", prob], ...]}
    final bigrams = <String, List<_Transition>>{};
    for (final entry in biData.entries) {
      bigrams[entry.key] = (entry.value as List)
          .map((t) => _Transition(t[0] as String, (t[1] as num).toDouble()))
          .toList();
    }

    // Parse starters: [[w1, w2, prob], ...] → "w1 w2" strings
    final startersList = <String>[];
    for (final s in metaData['starters'] as List) {
      final arr = s as List;
      startersList.add('${arr[0]} ${arr[1]}');
    }

    // Parse enders: [[word, prob], ...] → word strings
    final endersSet = <String>{};
    for (final e in metaData['enders'] as List) {
      final arr = e as List;
      endersSet.add(arr[0] as String);
    }

    return SentenceGenerator._(
      trigrams: trigrams,
      bigrams: bigrams,
      starters: startersList,
      enders: endersSet,
    );
  } catch (e) {
    // Markov model not available yet
    return null;
  }
});

/// Generate sentences for a typing test.
/// [tierVocab] constrains word choices to the given vocabulary set.
List<String> generateSentences(
  SentenceGenerator generator, {
  required int count,
  DifficultyTier tier = DifficultyTier.laerling,
  Set<String>? tierVocab,
}) {
  final config = _tierConfigs[tier] ?? const _TierConfig(0.8, 5, 12);
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
