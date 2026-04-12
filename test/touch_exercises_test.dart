import 'package:flutter_test/flutter_test.dart';
import 'package:typemagic/features/touch_training/touch_exercises.dart';

void main() {
  group('generateDrillWords', () {
    test('generates requested number of words', () {
      final words = generateDrillWords(['a', 's', 'd', 'f'], count: 15);
      expect(words.length, 15);
    });

    test('words are 3-5 characters long', () {
      final words = generateDrillWords(['a', 'b', 'c'], count: 50);
      for (final w in words) {
        expect(w.length, inInclusiveRange(3, 5));
      }
    });

    test('words only contain keys from the set', () {
      final keys = ['j', 'k', 'l', 'ø'];
      final words = generateDrillWords(keys, count: 30);
      for (final w in words) {
        for (final ch in w.split('')) {
          expect(keys, contains(ch));
        }
      }
    });
  });

  group('touchExercises', () {
    test('all exercises have unique IDs', () {
      final ids = touchExercises.map((e) => e.id).toSet();
      expect(ids.length, touchExercises.length);
    });

    test('all exercises have non-empty key lists', () {
      for (final ex in touchExercises) {
        expect(ex.keys, isNotEmpty, reason: '${ex.id} has no keys');
      }
    });
  });
}
