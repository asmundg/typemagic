import 'package:flutter_test/flutter_test.dart';
import 'package:typemagic/features/achievements/achievement_system.dart';

void main() {
  group('speedBadgeForWpm', () {
    test('returns null below 10 WPM', () {
      expect(speedBadgeForWpm(0), isNull);
      expect(speedBadgeForWpm(9.9), isNull);
    });

    test('returns Snegle at exactly 10 WPM', () {
      final badge = speedBadgeForWpm(10);
      expect(badge?.name, 'Snegle');
      expect(badge?.icon, '🐌');
    });

    test('returns Jogger at 25 WPM', () {
      expect(speedBadgeForWpm(25)?.name, 'Jogger');
    });

    test('returns highest earned badge', () {
      expect(speedBadgeForWpm(45)?.name, 'Sprinter');
      expect(speedBadgeForWpm(79)?.name, 'Lynet');
      expect(speedBadgeForWpm(80)?.name, 'Supersonisk');
      expect(speedBadgeForWpm(150)?.name, 'Mach 10');
    });
  });
}
