import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'sentence_generator_core.dart';

import 'sentence_generator_core.dart';

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

    return SentenceGenerator.fromJsonStrings(triJson, biJson, metaJson);
  } catch (e) {
    // Markov model not available yet
    return null;
  }
});
