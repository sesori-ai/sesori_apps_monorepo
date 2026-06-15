import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
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

      expect(
        settings.toJson(),
        equals({'sleepPrevention': 'always', 'releaseTrack': 'stable'}),
      );
    });

    test('toJson serializes off mode', () {
      const settings = BridgeSettings(sleepPrevention: SleepPreventionMode.off);

      expect(
        settings.toJson(),
        equals({'sleepPrevention': 'off', 'releaseTrack': 'stable'}),
      );
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

      expect(
        settings.toJson(),
        equals({'sleepPrevention': 'always', 'releaseTrack': 'stable'}),
      );
    });

    test('toJson includes enabledPlugins when set', () {
      const settings = BridgeSettings(enabledPlugins: ['opencode']);

      expect(
        settings.toJson(),
        equals({
          'sleepPrevention': 'always',
          'releaseTrack': 'stable',
          'enabledPlugins': ['opencode'],
        }),
      );
    });

    test('releaseTrack defaults to stable', () {
      const settings = BridgeSettings();

      expect(settings.releaseTrack, ReleaseTrack.stable);
    });

    test('fromJson parses the internal track', () {
      final settings = BridgeSettings.fromJson({'releaseTrack': 'internal'});

      expect(settings.releaseTrack, ReleaseTrack.internal);
    });

    test('fromJson defaults an unknown releaseTrack to stable', () {
      final settings = BridgeSettings.fromJson({'releaseTrack': 'nightly'});

      expect(settings.releaseTrack, ReleaseTrack.stable);
    });

    test('fromJson defaults a missing releaseTrack to stable', () {
      final settings = BridgeSettings.fromJson({'sleepPrevention': 'always'});

      expect(settings.releaseTrack, ReleaseTrack.stable);
    });

    test('fromJson defaults a non-string releaseTrack to stable', () {
      final settings = BridgeSettings.fromJson({'releaseTrack': 42});

      expect(settings.releaseTrack, ReleaseTrack.stable);
    });

    test('toJson always serializes the release track', () {
      const settings = BridgeSettings(releaseTrack: ReleaseTrack.internal);

      expect(settings.toJson()['releaseTrack'], equals('internal'));
    });

    test('copyWith changes only releaseTrack and preserves other fields', () {
      const settings = BridgeSettings(
        sleepPrevention: SleepPreventionMode.off,
        enabledPlugins: ['opencode'],
      );

      final updated = settings.copyWith(releaseTrack: ReleaseTrack.internal);

      expect(updated.releaseTrack, ReleaseTrack.internal);
      expect(updated.sleepPrevention, SleepPreventionMode.off);
      expect(updated.enabledPlugins, equals(['opencode']));
    });
  });
}
