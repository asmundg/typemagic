import 'dart:math';
import 'dart:ui';

/// A single touch-typing exercise definition.
class TouchExercise {
  final String id;
  final String name;
  final String description;
  final List<String> keys;
  final int row;
  final int col;

  const TouchExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.keys,
    required this.row,
    required this.col,
  });
}

/// Finger names for Norwegian UI.
enum Finger {
  leftPinky('V lillefinger'),
  leftRing('V ringfinger'),
  leftMiddle('V langfinger'),
  leftIndex('V pekefinger'),
  rightIndex('H pekefinger'),
  rightMiddle('H langfinger'),
  rightRing('H ringfinger'),
  rightPinky('H lillefinger');

  final String displayName;
  const Finger(this.displayName);
}

/// Norwegian QWERTY finger assignments.
const Map<String, Finger> keyToFinger = {
  // Left pinky
  'q': Finger.leftPinky, 'a': Finger.leftPinky, 'z': Finger.leftPinky,
  // Left ring
  'w': Finger.leftRing, 's': Finger.leftRing, 'x': Finger.leftRing,
  // Left middle
  'e': Finger.leftMiddle, 'd': Finger.leftMiddle, 'c': Finger.leftMiddle,
  // Left index
  'r': Finger.leftIndex, 'f': Finger.leftIndex, 'v': Finger.leftIndex,
  't': Finger.leftIndex, 'g': Finger.leftIndex, 'b': Finger.leftIndex,
  // Right index
  'y': Finger.rightIndex, 'h': Finger.rightIndex, 'n': Finger.rightIndex,
  'u': Finger.rightIndex, 'j': Finger.rightIndex, 'm': Finger.rightIndex,
  // Right middle
  'i': Finger.rightMiddle, 'k': Finger.rightMiddle,
  // Right ring
  'o': Finger.rightRing, 'l': Finger.rightRing,
  // Right pinky
  'p': Finger.rightPinky, 'ø': Finger.rightPinky, 'å': Finger.rightPinky,
  'æ': Finger.rightPinky,
};

/// Color associated with each finger for visual guides.
const Map<Finger, Color> fingerColors = {
  Finger.leftPinky: Color(0xFFE57373),
  Finger.leftRing: Color(0xFFFFB74D),
  Finger.leftMiddle: Color(0xFFFFF176),
  Finger.leftIndex: Color(0xFF81C784),
  Finger.rightIndex: Color(0xFF4FC3F7),
  Finger.rightMiddle: Color(0xFF9575CD),
  Finger.rightRing: Color(0xFFFFB74D),
  Finger.rightPinky: Color(0xFFE57373),
};

/// All available exercises, laid out in a grid.
/// Row 0 = home row exercises, row 1 = top row, row 2 = bottom row,
/// row 3 = reach/combo exercises.
const List<TouchExercise> touchExercises = [
  // Home row
  TouchExercise(
    id: 'home_left',
    name: 'Hvileraden V',
    description: 'Venstre hånd',
    keys: ['a', 's', 'd', 'f'],
    row: 0,
    col: 0,
  ),
  TouchExercise(
    id: 'home_right',
    name: 'Hvileraden H',
    description: 'Høyre hånd',
    keys: ['j', 'k', 'l', 'ø'],
    row: 0,
    col: 1,
  ),
  TouchExercise(
    id: 'home_full',
    name: 'Hele hvileraden',
    description: 'Alle hvileradtaster',
    keys: ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ø', 'æ'],
    row: 0,
    col: 2,
  ),
  // Top row
  TouchExercise(
    id: 'top_left',
    name: 'Øvre rad V',
    description: 'Venstre hånd',
    keys: ['q', 'w', 'e', 'r', 't'],
    row: 1,
    col: 0,
  ),
  TouchExercise(
    id: 'top_right',
    name: 'Øvre rad H',
    description: 'Høyre hånd',
    keys: ['y', 'u', 'i', 'o', 'p', 'å'],
    row: 1,
    col: 1,
  ),
  TouchExercise(
    id: 'top_full',
    name: 'Hele øvre rad',
    description: 'Øvre + hvileraden',
    keys: [
      'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 'å',
      'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ø', 'æ',
    ],
    row: 1,
    col: 2,
  ),
  // Bottom row
  TouchExercise(
    id: 'bottom_left',
    name: 'Nedre rad V',
    description: 'Venstre hånd',
    keys: ['z', 'x', 'c', 'v', 'b'],
    row: 2,
    col: 0,
  ),
  TouchExercise(
    id: 'bottom_right',
    name: 'Nedre rad H',
    description: 'Høyre hånd',
    keys: ['n', 'm'],
    row: 2,
    col: 1,
  ),
  TouchExercise(
    id: 'bottom_full',
    name: 'Hele nedre rad',
    description: 'Nedre + hvileraden',
    keys: [
      'z', 'x', 'c', 'v', 'b', 'n', 'm',
      'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ø', 'æ',
    ],
    row: 2,
    col: 2,
  ),
  // Full keyboard
  TouchExercise(
    id: 'full',
    name: 'Fullt tastatur',
    description: 'Alle taster',
    keys: [
      'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 'å',
      'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ø', 'æ',
      'z', 'x', 'c', 'v', 'b', 'n', 'm',
    ],
    row: 3,
    col: 1,
  ),
];

/// Number of grid rows in the exercise layout.
const int exerciseGridRows = 4;

/// Number of grid columns in the exercise layout.
const int exerciseGridCols = 3;

/// Generate drill words from a key set.
///
/// Produces [count] pseudo-words of 3-5 characters using only [keys].
List<String> generateDrillWords(List<String> keys, {int count = 20}) {
  final rng = Random();
  final words = <String>[];
  for (var i = 0; i < count; i++) {
    final len = 3 + rng.nextInt(3); // 3-5 chars
    final buf = StringBuffer();
    for (var j = 0; j < len; j++) {
      buf.write(keys[rng.nextInt(keys.length)]);
    }
    words.add(buf.toString());
  }
  return words;
}
