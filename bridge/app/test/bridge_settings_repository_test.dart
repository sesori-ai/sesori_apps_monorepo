import 'dart:convert';

import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeSettingsRepository', () {
    test('creates defaults when config is missing', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.plugins.disabledPluginIds, isEmpty);
      expect(repository.currentSettings, same(settings));
      expect(api.lastWrittenConfig, _defaultJson);
    });

    test('loads valid plugin settings without rewriting', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"sleepPrevention":"off","plugins":{"disabled":["cursor"]}}',
      );
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.off);
      expect(settings.plugins.disabledPluginIds, {'cursor'});
      expect(api.writeCount, 0);
    });

    test('does not replace corrupted JSON with an empty denylist', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(api: api);

      await expectLater(repository.loadSettings(), throwsA(isA<FormatException>()));
      expect(api.writeCount, 0);
    });

    test('does not replace a malformed denylist', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"plugins":{"disabled":["cursor",42]}}',
      );
      final repository = BridgeSettingsRepository(api: api);

      await expectLater(repository.loadSettings(), throwsA(isA<PluginSettingsFormatException>()));
      expect(api.writeCount, 0);
    });

    test('does not replace explicit null plugin policy', () async {
      for (final storedConfig in ['{"plugins":null}', '{"plugins":{"disabled":null}}']) {
        final api = FakeBridgeSettingsApi(readResult: storedConfig);
        final repository = BridgeSettingsRepository(api: api);

        await expectLater(repository.loadSettings(), throwsA(isA<PluginSettingsFormatException>()));
        expect(api.writeCount, 0);
      }
    });

    test('repairs one malformed timeout without dropping policy or unknown fields', () async {
      final api = FakeBridgeSettingsApi(
        readResult: jsonEncode({
          'plugins': {
            'disabled': ['cursor'],
            'opencode': {'idleTimeoutMins': 'ten', 'futureOption': true},
            'future-plugin': {'futureOption': 'kept'},
          },
        }),
      );
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.plugins.disabledPluginIds, {'cursor'});
      expect(settings.plugins.idleTimeoutMinsFor(pluginId: 'opencode'), defaultPluginIdleTimeoutMins);
      final written = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      final plugins = written['plugins'] as Map<String, dynamic>;
      expect(plugins['disabled'], ['cursor']);
      expect(plugins['opencode'], {'futureOption': true});
      expect(plugins['future-plugin'], {'futureOption': 'kept'});
    });

    test('repairs an explicit null timeout locally', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"plugins":{"disabled":["cursor"],"opencode":{"idleTimeoutMins":null}}}',
      );
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.plugins.disabledPluginIds, {'cursor'});
      expect(settings.plugins.settingsByPluginId, isNot(contains('opencode')));
      final written = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect((written['plugins'] as Map)['disabled'], ['cursor']);
      expect(written['plugins'] as Map, isNot(contains('opencode')));
    });

    test('ensureConfigExists does not parse or rewrite an existing file', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(api: api);

      await repository.ensureConfigExists();

      expect(api.writeCount, 0);
    });

    test('saveSettings pretty prints and updates the current snapshot', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(api: api);
      const settings = BridgeSettings(
        sleepPrevention: SleepPreventionMode.off,
        plugins: BridgePluginSettings(disabledPluginIds: {'cursor'}),
      );

      await repository.saveSettings(settings: settings);

      expect(repository.currentSettings, same(settings));
      expect(api.lastWrittenConfig, contains('"disabled": [\n      "cursor"'));
    });

    test('updates denylist while preserving plugin objects and dropping abandoned allowlists', () async {
      final api = FakeBridgeSettingsApi(
        readResult: jsonEncode({
          'enabledPlugins': ['opencode'],
          'plugins': {
            'future-plugin': {'futureOption': 'kept'},
          },
        }),
      );
      final repository = BridgeSettingsRepository(api: api);

      final updated = await repository.updatePluginDisabled(pluginId: 'cursor', disabled: true);

      expect(updated.plugins.disabledPluginIds, {'cursor'});
      final written = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(written, isNot(contains('enabledPlugins')));
      expect((written['plugins'] as Map)['future-plugin'], {'futureOption': 'kept'});
    });

    test('release track and yolo updates preserve plugin policy', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"plugins":{"disabled":["cursor"]}}',
      );
      final repository = BridgeSettingsRepository(api: api);

      await repository.updateReleaseTrack(track: ReleaseTrack.internal);
      final afterTrack = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(afterTrack['releaseTrack'], 'internal');
      expect((afterTrack['plugins'] as Map)['disabled'], ['cursor']);

      await repository.updateYolo(enabled: true);
      final afterYolo = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(afterYolo['yolo'], isTrue);
      expect((afterYolo['plugins'] as Map)['disabled'], ['cursor']);
    });

    test('configFilePath delegates to the API', () {
      final repository = BridgeSettingsRepository(
        api: FakeBridgeSettingsApi(readResult: null, configFilePath: '/tmp/custom-config.json'),
      );

      expect(repository.configFilePath, '/tmp/custom-config.json');
    });
  });
}

const _defaultJson = '{\n  "sleepPrevention": "always",\n  "yolo": false,\n  "releaseTrack": "stable"\n}';

class FakeBridgeSettingsApi implements BridgeSettingsApi {
  @override
  final String configFilePath;

  final String? readResult;
  String? lastWrittenConfig;
  int writeCount = 0;

  FakeBridgeSettingsApi({
    required this.readResult,
    this.configFilePath = '/tmp/config.json',
  });

  @override
  Future<String?> readConfig() async => readResult;

  @override
  Future<void> writeConfig(String jsonContent) async {
    lastWrittenConfig = jsonContent;
    writeCount += 1;
  }
}
