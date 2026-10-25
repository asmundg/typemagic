import 'package:flutter_test/flutter_test.dart';
import 'package:typemagic/core/updater.dart';

void main() {
  test('isNewerVersion compares numerically, ignoring build suffix', () {
    expect(isNewerVersion('0.5.0', '0.4.0'), isTrue);
    expect(isNewerVersion('0.10.0', '0.9.3'), isTrue);
    expect(isNewerVersion('1.0.0', '0.99.99'), isTrue);
    expect(isNewerVersion('0.4.1', '0.4.0+7'), isTrue);
    expect(isNewerVersion('0.4.0', '0.4.0'), isFalse);
    expect(isNewerVersion('0.4.0', '0.4.0+3'), isFalse);
    expect(isNewerVersion('0.4.0', '1.0.0'), isFalse);
    expect(isNewerVersion('0.3.9', '0.4.0'), isFalse);
  });
}
