import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
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

    test('fromJson parses off mode', () {
      final settings = BridgeSettings.fromJson({'sleepPrevention': 'off'});

      expect(settings.sleepPrevention, SleepPreventionMode.off);
    });

    test('fromJson defaults invalid values to always', () {
      final settings = BridgeSettings.fromJson({'sleepPrevention': 'sometimes'});

      expect(settings.sleepPrevention, SleepPreventionMode.always);
    });

    test('fromJson defaults missing key to always', () {
      final settings = BridgeSettings.fromJson({});

      expect(settings.sleepPrevention, SleepPreventionMode.always);
    });

    test('toJson serializes always mode', () {
      const settings = BridgeSettings(sleepPrevention: SleepPreventionMode.always);

      expect(settings.toJson(), equals({'sleepPrevention': 'always'}));
    });

    test('toJson serializes off mode', () {
      const settings = BridgeSettings(sleepPrevention: SleepPreventionMode.off);

      expect(settings.toJson(), equals({'sleepPrevention': 'off'}));
    });
  });
}
