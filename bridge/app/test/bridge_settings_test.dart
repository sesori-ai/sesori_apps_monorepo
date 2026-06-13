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

    test('enabledPlugins defaults to unset', () {
      const settings = BridgeSettings();

      expect(settings.enabledPlugins, isNull);
    });

    test('fromJson parses enabledPlugins entries', () {
      final settings = BridgeSettings.fromJson({
        'enabledPlugins': ['opencode'],
      });

      expect(settings.enabledPlugins, equals(['opencode']));
    });

    test('fromJson treats a missing enabledPlugins key as unset', () {
      final settings = BridgeSettings.fromJson({'sleepPrevention': 'always'});

      expect(settings.enabledPlugins, isNull);
    });

    test('fromJson treats a non-list enabledPlugins as unset', () {
      final settings = BridgeSettings.fromJson({'enabledPlugins': 'opencode'});

      expect(settings.enabledPlugins, isNull);
    });

    test('fromJson keeps only string entries of enabledPlugins', () {
      final settings = BridgeSettings.fromJson({
        'enabledPlugins': ['opencode', 42, null],
      });

      expect(settings.enabledPlugins, equals(['opencode']));
    });

    test('toJson omits enabledPlugins when unset, keeping the defaults file shape', () {
      const settings = BridgeSettings();

      expect(settings.toJson(), equals({'sleepPrevention': 'always'}));
    });

    test('toJson includes enabledPlugins when set', () {
      const settings = BridgeSettings(enabledPlugins: ['opencode']);

      expect(
        settings.toJson(),
        equals({
          'sleepPrevention': 'always',
          'enabledPlugins': ['opencode'],
        }),
      );
    });
  });
}
