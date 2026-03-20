import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';

/// A single word entry from the tiered dictionary
class DictionaryWord {
  final String word;
  final int freqRank;
  final int length;
  final bool hasSpecial;

  const DictionaryWord({
    required this.word,
    required this.freqRank,
    required this.length,
    required this.hasSpecial,
  });

  factory DictionaryWord.fromJson(Map<String, dynamic> json) {
    return DictionaryWord(
      word: json['word'] as String,
      freqRank: json['freq_rank'] as int? ?? 99999,
      length: json['length'] as int? ?? (json['word'] as String).length,
      hasSpecial: json['has_special'] as bool? ?? false,
    );
  }
}

/// Tiered dictionary with difficulty-based word selection
class WordProvider {
  final Map<DifficultyTier, List<DictionaryWord>> _tiers;
  final List<String> _fallbackWords;
  final Random _random;
  final Set<String> _weakWords = {};

  WordProvider(this._tiers, this._fallbackWords) : _random = Random();

  /// Get [count] random words respecting tier and special char preferences.
  /// Avoids consecutive duplicates and limits repeats.
  List<String> getWords(
    int count, {
    DifficultyTier maxTier = DifficultyTier.laerling,
    bool specialCharFocus = false,
  }) {
    final pool = _buildWordPool(maxTier, specialCharFocus);
    if (pool.isEmpty) return _fallbackSelection(count);

    final selected = <String>[];
    final weakInject = _weakWords.toList();
    final usedCounts = <String, int>{};

    // Max times any word can appear — scale with how many we need vs pool size
    final maxRepeats = count > pool.length ? (count / pool.length).ceil() + 1 : 1;

    for (var i = 0; i < count; i++) {
      // 20% chance to inject a weak word if any exist
      if (weakInject.isNotEmpty && _random.nextDouble() < 0.2) {
        final w = weakInject[_random.nextInt(weakInject.length)];
        selected.add(w);
        continue;
      }

      // Try up to 10 times to find a non-duplicate word
      String? pick;
      for (var attempt = 0; attempt < 10; attempt++) {
        final candidate = pool[_random.nextInt(pool.length)];
        final used = usedCounts[candidate] ?? 0;
        // Reject if: already at max repeats, or same as previous word
        if (used >= maxRepeats) continue;
        if (selected.isNotEmpty && selected.last == candidate) continue;
        pick = candidate;
        break;
      }
      pick ??= pool[_random.nextInt(pool.length)];
      selected.add(pick);
      usedCounts[pick] = (usedCounts[pick] ?? 0) + 1;
    }
    return selected;
  }

  /// Get enough words to fill roughly [seconds] of typing
  List<String> getWordsForDuration(
    int seconds, {
    DifficultyTier maxTier = DifficultyTier.laerling,
    bool specialCharFocus = false,
  }) {
    final estimatedWords = (seconds * 40 / 60 * 1.5).ceil();
    return getWords(estimatedWords,
        maxTier: maxTier, specialCharFocus: specialCharFocus);
  }

  /// Record a word the user struggled with
  void recordWeakWord(String word) => _weakWords.add(word);

  /// Clear weak words
  void clearWeakWords() => _weakWords.clear();

  /// Build a weighted word pool from tiers up to maxTier
  List<String> _buildWordPool(
      DifficultyTier maxTier, bool specialCharFocus) {
    final pool = <String>[];
    for (final tier in DifficultyTier.values) {
      if (tier.level > maxTier.level) break;
      final words = _tiers[tier] ?? [];

      // Weight: current tier gets more representation
      final weight = tier == maxTier ? 3 : 1;
      for (var w = 0; w < weight; w++) {
        for (final dw in words) {
          if (specialCharFocus && !dw.hasSpecial) continue;
          pool.add(dw.word);
        }
      }
    }
    // If specialCharFocus yielded nothing, fall back to all words
    if (pool.isEmpty && specialCharFocus) {
      return _buildWordPool(maxTier, false);
    }
    return pool;
  }

  List<String> _fallbackSelection(int count) {
    return List.generate(
        count, (_) => _fallbackWords[_random.nextInt(_fallbackWords.length)]);
  }

  int get totalWords =>
      _tiers.values.fold(0, (sum, list) => sum + list.length);

  int wordsInTier(DifficultyTier tier) => _tiers[tier]?.length ?? 0;

  /// Returns a lowercase vocabulary set for all tiers up to [maxTier].
  /// Used to constrain the sentence generator's Markov sampling.
  Set<String> getVocabularySet(DifficultyTier maxTier) {
    final vocab = <String>{};
    for (final tier in DifficultyTier.values) {
      if (tier.level > maxTier.level) break;
      final words = _tiers[tier] ?? [];
      vocab.addAll(words.map((w) => w.word.toLowerCase()));
    }
    return vocab;
  }
}

/// Loads the tiered word provider from bundled assets
final wordProviderFutureProvider = FutureProvider<WordProvider>((ref) async {
  final tiers = <DifficultyTier, List<DictionaryWord>>{};
  final fallback = <String>[];

  for (final tier in DifficultyTier.values) {
    try {
      final jsonString = await rootBundle
          .loadString('assets/dictionaries/tier${tier.level}.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final words = (data['words'] as List)
          .map((w) => DictionaryWord.fromJson(w as Map<String, dynamic>))
          .toList();
      tiers[tier] = words;
      if (tier.level <= 2) {
        fallback.addAll(words.map((w) => w.word));
      }
    } catch (_) {
      // Tier file not available yet — skip
    }
  }

  // Fallback: load the old simple word list if no tiers loaded
  if (tiers.isEmpty) {
    try {
      final jsonString =
          await rootBundle.loadString('assets/dictionaries/nb_common_500.json');
      final List<dynamic> words = json.decode(jsonString);
      final cleaned = words
          .cast<String>()
          .map((w) => w.toLowerCase())
          .toSet()
          .where((w) => w.length >= 2)
          .toList();
      tiers[DifficultyTier.nybegynner] = cleaned
          .map((w) => DictionaryWord(
                word: w,
                freqRank: 0,
                length: w.length,
                hasSpecial: w.contains(RegExp('[æøåÆØÅ]')),
              ))
          .toList();
      fallback.addAll(cleaned);
    } catch (_) {
      fallback.addAll(const ['laster', 'ord', 'tekst']);
    }
  }

  if (fallback.isEmpty) {
    fallback.addAll(
        tiers.values.expand((list) => list.map((w) => w.word)).take(100));
  }

  return WordProvider(tiers, fallback);
});
