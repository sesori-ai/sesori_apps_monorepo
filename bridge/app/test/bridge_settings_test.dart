import 'package:sesori_bridge/src/foundation/bridge_settings.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeSettings', () {
    test('defaults to always sleep prevention', () {
      const settings = BridgeSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
    });

    test('can disable sleep prevention', () {
      const settings = BridgeSettings(
        sleepPrevention: SleepPreventionMode.off,
      );

      expect(settings.sleepPrevention, SleepPreventionMode.off);
    });
  });
}
