/// Generates example sentences for each difficulty tier using a fixed seed.
///
/// Usage:
///   dart run tools/generate_examples.dart [--seed=42] [--count=5]
///
/// Output is written to docs/example_sentences.md so it can be tracked in git.
/// Re-running with the same seed produces identical output — use this to verify
/// generator changes.
import 'dart:convert';
import 'dart:io';

// We can't import from package:typemagic/... because it pulls in Flutter.
// Instead, load the core file directly via a relative import.
import '../lib/features/sentence_gen/sentence_generator_core.dart';
import '../lib/core/models.dart';

void main(List<String> args) {
  final seed = _intArg(args, 'seed') ?? 42;
  final count = _intArg(args, 'count') ?? 5;
  final assetDir = 'assets/markov';
  final dictDir = 'assets/dictionaries';

  // Load generator
  final generator = SentenceGenerator.loadFromDirectory(assetDir, seed: seed);
  if (generator == null) {
    stderr.writeln('ERROR: Could not load Markov model from $assetDir');
    exit(1);
  }

  // Load dictionaries for vocabulary constraints
  final vocabs = <DifficultyTier, Set<String>>{};
  final cumulative = <String>{};
  for (final tier in DifficultyTier.values) {
    final file = File('$dictDir/tier${tier.level}.json');
    if (file.existsSync()) {
      final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final words = (data['words'] as List)
          .map((w) => (w as Map<String, dynamic>)['word'] as String)
          .map((w) => w.toLowerCase())
          .toSet();
      cumulative.addAll(words);
    }
    vocabs[tier] = Set.of(cumulative);
  }

  // Generate
  final buf = StringBuffer();
  buf.writeln('# Example Sentences by Difficulty Tier');
  buf.writeln();
  buf.writeln('Generated with seed `$seed`, $count sentences per tier.');
  buf.writeln();
  buf.writeln('Regenerate with:');
  buf.writeln('```');
  buf.writeln('dart run tools/generate_examples.dart --seed=$seed --count=$count');
  buf.writeln('```');
  buf.writeln();

  for (final tier in DifficultyTier.values) {
    final config = tierConfigs[tier]!;
    final vocab = vocabs[tier];

    buf.writeln('## ${tier.displayName} (tier ${tier.level})');
    buf.writeln();
    buf.writeln(
        '${tier.description} · temperature ${config.temperature} · '
        '${config.minWords}–${config.maxWords} words');
    buf.writeln();

    final sentences = generateSentences(
      generator,
      count: count,
      tier: tier,
      tierVocab: vocab,
    );

    for (var i = 0; i < sentences.length; i++) {
      buf.writeln('${i + 1}. ${sentences[i]}');
    }
    buf.writeln();
  }

  final outFile = File('docs/example_sentences.md');
  outFile.writeAsStringSync(buf.toString());
  stdout.writeln('Wrote ${outFile.path} (seed=$seed, $count per tier)');
}

int? _intArg(List<String> args, String name) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) {
      return int.tryParse(arg.split('=').last);
    }
  }
  return null;
}
