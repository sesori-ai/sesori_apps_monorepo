import 'dart:async';
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
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      final settings = await repository.loadSettings();

      expect(settings.plugins.disabledPluginIds, isEmpty);
      expect(settings.pullRequestRefreshIntervalSeconds, defaultPullRequestRefreshIntervalSeconds);
      expect(settings.warmUpPluginsOnSessionOpen, isTrue);
      expect(repository.currentSettings, same(settings));
      expect(api.lastWrittenConfig, _defaultJson);
    });

    test('loads valid plugin settings without rewriting', () async {
      final api = FakeBridgeSettingsApi(
        readResult:
            '{"sleepPrevention":"off","pullRequestRefreshIntervalSeconds":30,'
            '"warmUpPluginsOnSessionOpen":true,"plugins":{"disabled":["cursor"]}}',
      );
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.off);
      expect(settings.plugins.disabledPluginIds, {'cursor'});
      expect(api.writeCount, 0);
    });

    test('writes the default when the PR refresh interval key is missing', () async {
      final api = FakeBridgeSettingsApi(readResult: '{"sleepPrevention":"off"}');
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      final settings = await repository.loadSettings();

      expect(settings.pullRequestRefreshIntervalSeconds, defaultPullRequestRefreshIntervalSeconds);
      expect((jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>)['pullRequestRefreshIntervalSeconds'], 30);
    });

    test('repairs a missing or malformed session-open warm-up setting', () async {
      for (final config in [
        '{"pullRequestRefreshIntervalSeconds":30}',
        '{"pullRequestRefreshIntervalSeconds":30,"warmUpPluginsOnSessionOpen":"true"}',
      ]) {
        final api = FakeBridgeSettingsApi(readResult: config);
        final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

        final settings = await repository.loadSettings();

        expect(settings.warmUpPluginsOnSessionOpen, isTrue);
        expect((jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>)['warmUpPluginsOnSessionOpen'], isTrue);
      }
    });

    test('repairs malformed and out-of-range PR refresh intervals', () async {
      for (final rawValue in <Object?>['30', 14, 3601, null]) {
        final api = FakeBridgeSettingsApi(
          readResult: jsonEncode({'pullRequestRefreshIntervalSeconds': rawValue}),
        );
        final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

        final settings = await repository.loadSettings();

        expect(settings.pullRequestRefreshIntervalSeconds, defaultPullRequestRefreshIntervalSeconds);
        expect((jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>)['pullRequestRefreshIntervalSeconds'], 30);
      }
    });

    test('does not replace corrupted JSON with an empty denylist', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      await expectLater(repository.loadSettings(), throwsA(isA<FormatException>()));
      expect(api.writeCount, 0);
    });

    test('does not replace a malformed denylist', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"plugins":{"disabled":["cursor",42]}}',
      );
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      await expectLater(repository.loadSettings(), throwsA(isA<PluginSettingsFormatException>()));
      expect(api.writeCount, 0);
    });

    test('does not replace explicit null plugin policy', () async {
      for (final storedConfig in ['{"plugins":null}', '{"plugins":{"disabled":null}}']) {
        final api = FakeBridgeSettingsApi(readResult: storedConfig);
        final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

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
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

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
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      final settings = await repository.loadSettings();

      expect(settings.plugins.disabledPluginIds, {'cursor'});
      expect(settings.plugins.settingsByPluginId, isNot(contains('opencode')));
      final written = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect((written['plugins'] as Map)['disabled'], ['cursor']);
      expect(written['plugins'] as Map, isNot(contains('opencode')));
    });

    test('ensureConfigExists does not parse or rewrite an existing file', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      await repository.ensureConfigExists();

      expect(api.writeCount, 0);
    });

    test('mutateSettings pretty prints, updates, and publishes the current snapshot', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      final changes = <BridgeSettingsChange>[];
      final subscription = repository.settingsChanges.listen(changes.add);

      final settings = await repository.mutateSettings(
        mutation: ({required current}) => current.copyWith(
          sleepPrevention: SleepPreventionMode.off,
          plugins: const BridgePluginSettings(disabledPluginIds: {'cursor'}),
        ),
      );

      expect(repository.currentSettings, same(settings));
      expect(api.lastWrittenConfig, contains('"disabled": [\n      "cursor"'));
      expect(changes, hasLength(1));
      expect(changes.single.previous.pullRequestRefreshIntervalSeconds, 30);
      expect(changes.single.current, same(settings));
      await subscription.cancel();
      await repository.dispose();
    });

    test('serializes plugin and PR interval mutations without losing either field', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"pullRequestRefreshIntervalSeconds":30}',
      );
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      api.writeGate = Completer<void>();

      final pluginMutation = repository.mutateSettings(
        mutation: ({required current}) => current.copyWith(
          plugins: current.plugins.withPluginDisabled(pluginId: 'cursor', disabled: true),
        ),
      );
      await api.writeStarted.future;
      final intervalMutation = repository.mutateSettings(
        mutation: ({required current}) => current.copyWith(pullRequestRefreshIntervalSeconds: 45),
      );

      api.writeGate!.complete();
      await Future.wait([pluginMutation, intervalMutation]);

      expect(repository.currentSettings.plugins.disabledPluginIds, {'cursor'});
      expect(repository.currentSettings.pullRequestRefreshIntervalSeconds, 45);
      final written = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect((written['plugins'] as Map)['disabled'], ['cursor']);
      expect(written['pullRequestRefreshIntervalSeconds'], 45);
      await repository.dispose();
    });

    test('rejects an invalid interval mutation before commit and keeps the tail usable', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"pullRequestRefreshIntervalSeconds":30,"warmUpPluginsOnSessionOpen":true}',
      );
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      final changes = <BridgeSettingsChange>[];
      final subscription = repository.settingsChanges.listen(changes.add);

      await expectLater(
        repository.mutateSettings(
          mutation: ({required current}) => current.copyWith(pullRequestRefreshIntervalSeconds: 14),
        ),
        throwsA(isA<PullRequestRefreshIntervalFormatException>()),
      );

      expect(api.writeCount, 0);
      expect(repository.currentSettings.pullRequestRefreshIntervalSeconds, 30);
      expect(changes, isEmpty);
      final recovered = await repository.mutateSettings(
        mutation: ({required current}) => current.copyWith(pullRequestRefreshIntervalSeconds: 45),
      );
      expect(recovered.pullRequestRefreshIntervalSeconds, 45);
      await subscription.cancel();
      await repository.dispose();
    });

    test('manual file edits have no live effect but load in a new repository', () async {
      final api = FakeBridgeSettingsApi(readResult: '{"pullRequestRefreshIntervalSeconds":30}');
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();

      api.readResult = '{"pullRequestRefreshIntervalSeconds":60}';

      expect(repository.currentSettings.pullRequestRefreshIntervalSeconds, 30);
      final restartedRepository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      expect((await restartedRepository.loadSettings()).pullRequestRefreshIntervalSeconds, 60);
      await repository.dispose();
      await restartedRepository.dispose();
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
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      final updated = await repository.updatePluginDisabled(pluginId: 'cursor', disabled: true);

      expect(updated.plugins.disabledPluginIds, {'cursor'});
      final written = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(written, isNot(contains('enabledPlugins')));
      expect((written['plugins'] as Map)['future-plugin'], {'futureOption': 'kept'});
    });

    test('release track, yolo, and warm-up updates preserve plugin policy', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"plugins":{"disabled":["cursor"]}}',
      );
      final repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);

      await repository.updateReleaseTrack(track: ReleaseTrack.internal);
      final afterTrack = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(afterTrack['releaseTrack'], 'internal');
      expect((afterTrack['plugins'] as Map)['disabled'], ['cursor']);

      await repository.updateYolo(enabled: true);
      final afterYolo = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(afterYolo['yolo'], isTrue);
      expect((afterYolo['plugins'] as Map)['disabled'], ['cursor']);

      await repository.updateWarmUpPluginsOnSessionOpen(enabled: false);
      final afterWarmup = jsonDecode(api.lastWrittenConfig!) as Map<String, dynamic>;
      expect(afterWarmup['warmUpPluginsOnSessionOpen'], isFalse);
      expect((afterWarmup['plugins'] as Map)['disabled'], ['cursor']);
    });

    test('reports unavailable default editor explicitly', () async {
      final repository = BridgeSettingsRepository(
        defaultEditorApi: null,
        api: FakeBridgeSettingsApi(readResult: null),
      );

      expect(repository.openInDefaultEditor, throwsA(isA<StateError>()));
    });

    test('configFilePath delegates to the API', () {
      final repository = BridgeSettingsRepository(
        defaultEditorApi: null,
        api: FakeBridgeSettingsApi(readResult: null, configFilePath: '/tmp/custom-config.json'),
      );

      expect(repository.configFilePath, '/tmp/custom-config.json');
    });
  });
}

const _defaultJson =
    '{\n  "sleepPrevention": "always",\n  "yolo": false,\n  "releaseTrack": "stable",\n  "pullRequestRefreshIntervalSeconds": 30,\n  "warmUpPluginsOnSessionOpen": true\n}';

class FakeBridgeSettingsApi({
  required var String? readResult,
  @override final String configFilePath = '/tmp/config.json',
}) implements BridgeSettingsApi {
  String? lastWrittenConfig;
  int writeCount = 0;
  Completer<void>? writeGate;
  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<String?> readConfig() async => readResult;

  @override
  Future<void> writeConfig(String jsonContent) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    lastWrittenConfig = jsonContent;
    writeCount += 1;
  }
}
