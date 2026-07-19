import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeSettings', () {
    test('uses stable non-plugin defaults and omits an untouched plugins root', () {
      const settings = BridgeSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(settings.yolo, isFalse);
      expect(settings.releaseTrack, ReleaseTrack.stable);
      expect(settings.plugins.disabledPluginIds, isEmpty);
      expect(settings.plugins.idleTimeoutMinsFor(pluginId: 'opencode'), defaultPluginIdleTimeoutMins);
      expect(settings.toJson(), {
        'sleepPrevention': 'always',
        'yolo': false,
        'releaseTrack': 'stable',
      });
    });

    test('parses existing bridge settings', () {
      final settings = BridgeSettings.fromJson({
        'sleepPrevention': 'off',
        'yolo': true,
        'releaseTrack': 'internal',
      });

      expect(settings.sleepPrevention, SleepPreventionMode.off);
      expect(settings.yolo, isTrue);
      expect(settings.releaseTrack, ReleaseTrack.internal);
    });

    test('invalid legacy scalar values retain their established defaults', () {
      final settings = BridgeSettings.fromJson({
        'sleepPrevention': 'sometimes',
        'yolo': 'true',
        'releaseTrack': 'nightly',
      });

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(settings.yolo, isFalse);
      expect(settings.releaseTrack, ReleaseTrack.stable);
    });

    test('parses denylist and inherited numeric idle timeouts', () {
      final settings = BridgeSettings.fromJson({
        'plugins': {
          'disabled': ['cursor'],
          'default': {'idleTimeoutMins': 30},
          'opencode': {'idleTimeoutMins': 0},
        },
      });

      expect(settings.plugins.isDisabled(pluginId: 'cursor'), isTrue);
      expect(settings.plugins.isDisabled(pluginId: 'opencode'), isFalse);
      expect(settings.plugins.idleTimeoutMinsFor(pluginId: 'opencode'), 0);
      expect(settings.plugins.idleTimeoutMinsFor(pluginId: 'codex'), 30);
    });

    test('preserves exact negative timeout values', () {
      final settings = BridgeSettings.fromJson({
        'plugins': {
          'opencode': {'idleTimeoutMins': -7},
        },
      });

      expect(settings.plugins.idleTimeoutMinsFor(pluginId: 'opencode'), -7);
      expect((settings.toJson()['plugins'] as Map)['opencode'], {'idleTimeoutMins': -7});
    });

    test('preserves unknown plugin objects and fields', () {
      final settings = BridgeSettings.fromJson({
        'plugins': {
          'future-plugin': {'idleTimeoutMins': 5, 'futureOption': 'kept'},
          'opencode': {'futureOption': true},
        },
      });

      final plugins = settings.toJson()['plugins'] as Map<String, dynamic>;
      expect(plugins['future-plugin'], {'futureOption': 'kept', 'idleTimeoutMins': 5});
      expect(plugins['opencode'], {'futureOption': true});
    });

    test('canonicalizes duplicate disabled IDs and write order', () {
      final settings = BridgeSettings.fromJson({
        'plugins': {
          'disabled': ['opencode', 'cursor', 'opencode'],
        },
      });

      expect((settings.toJson()['plugins'] as Map)['disabled'], ['cursor', 'opencode']);
    });

    test('ignores abandoned allowlist fields', () {
      final settings = BridgeSettings.fromJson({
        'enabledPlugins': ['opencode'],
        'remoteEnabledPlugins': ['cursor'],
      });

      expect(settings.plugins.disabledPluginIds, isEmpty);
      expect(settings.toJson(), isNot(anyOf(contains('enabledPlugins'), contains('remoteEnabledPlugins'))));
    });

    test('rejects malformed plugin root and denylist', () {
      expect(
        () => BridgeSettings.fromJson({'plugins': 'opencode'}),
        throwsA(isA<PluginSettingsFormatException>()),
      );
      expect(
        () => BridgeSettings.fromJson({'plugins': null}),
        throwsA(isA<PluginSettingsFormatException>()),
      );
      expect(
        () => BridgeSettings.fromJson({
          'plugins': {
            'disabled': ['opencode', 42],
          },
        }),
        throwsA(isA<PluginSettingsFormatException>()),
      );
      expect(
        () => BridgeSettings.fromJson({
          'plugins': {
            'disabled': [''],
          },
        }),
        throwsA(isA<PluginSettingsFormatException>()),
      );
      expect(
        () => BridgeSettings.fromJson({
          'plugins': {'disabled': null},
        }),
        throwsA(isA<PluginSettingsFormatException>()),
      );
      expect(
        () => BridgeSettings.fromJson({
          'plugins': {'': <String, dynamic>{}},
        }),
        throwsA(isA<PluginSettingsFormatException>()),
      );
    });

    test('identifies malformed timeout at its exact entry', () {
      expect(
        () => BridgeSettings.fromJson({
          'plugins': {
            'opencode': {'idleTimeoutMins': 'ten'},
          },
        }),
        throwsA(
          isA<PluginIdleTimeoutFormatException>().having(
            (error) => error.entryName,
            'entryName',
            'opencode',
          ),
        ),
      );
      expect(
        () => BridgeSettings.fromJson({
          'plugins': {
            'opencode': {'idleTimeoutMins': null},
          },
        }),
        throwsA(
          isA<PluginIdleTimeoutFormatException>().having(
            (error) => error.entryName,
            'entryName',
            'opencode',
          ),
        ),
      );
    });

    test('denylist mutation preserves lifecycle objects', () {
      final original = BridgeSettings.fromJson({
        'plugins': {
          'future-plugin': {'futureOption': 'kept'},
          'opencode': {'idleTimeoutMins': 2},
        },
      });

      final updated = original.copyWith(
        plugins: original.plugins.withPluginDisabled(pluginId: 'cursor', disabled: true),
      );

      expect(updated.plugins.disabledPluginIds, {'cursor'});
      expect(updated.plugins.idleTimeoutMinsFor(pluginId: 'opencode'), 2);
      expect((updated.toJson()['plugins'] as Map)['future-plugin'], {'futureOption': 'kept'});
    });

    test('apply-all clears timeout overrides while preserving unknown fields', () {
      final original = BridgeSettings.fromJson({
        'plugins': {
          'opencode': {'idleTimeoutMins': 2, 'futureOption': true},
        },
      });

      final updated = original.plugins.withDefaultIdleTimeout(idleTimeoutMins: 15, clearOverrides: true);
      final json = updated.toJson();

      expect(json['default'], {'idleTimeoutMins': 15});
      expect(json['opencode'], {'futureOption': true});
    });

    test('copyWith changes one legacy setting and preserves plugin policy', () {
      const settings = BridgeSettings(
        sleepPrevention: SleepPreventionMode.off,
        plugins: BridgePluginSettings(disabledPluginIds: {'cursor'}),
      );

      final updated = settings.copyWith(releaseTrack: ReleaseTrack.internal, yolo: true);

      expect(updated.sleepPrevention, SleepPreventionMode.off);
      expect(updated.plugins.disabledPluginIds, {'cursor'});
      expect(updated.releaseTrack, ReleaseTrack.internal);
      expect(updated.yolo, isTrue);
    });
  });
}
