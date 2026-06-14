import 'dart:io';

import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeSettingsRepository', () {
    test('loadSettings creates and returns defaults when config is missing', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(api.lastWrittenConfig, equals(_defaultJson));
    });

    test('loadSettings parses valid sleep prevention mode', () async {
      final api = FakeBridgeSettingsApi(readResult: '{"sleepPrevention":"off"}');
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.off);
      expect(api.writeCount, equals(0));
    });

    test('loadSettings defaults missing sleepPrevention without rewriting', () async {
      final api = FakeBridgeSettingsApi(readResult: '{}');
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(api.writeCount, equals(0));
    });

    test('loadSettings defaults invalid sleepPrevention without rewriting', () async {
      final api = FakeBridgeSettingsApi(readResult: '{"sleepPrevention":"sometimes"}');
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(api.writeCount, equals(0));
    });

    test('loadSettings recovers from corrupted JSON by overwriting defaults', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(api.lastWrittenConfig, equals(_defaultJson));
    });

    test('loadSettings treats non-object JSON as corrupted and overwrites defaults', () async {
      final api = FakeBridgeSettingsApi(readResult: '[]');
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.loadSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(api.lastWrittenConfig, equals(_defaultJson));
    });

    test('peekSettings returns defaults without writing when config is missing', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.peekSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(settings.enabledPlugins, isNull);
      expect(api.writeCount, equals(0));
    });

    test('peekSettings parses a valid config', () async {
      final api = FakeBridgeSettingsApi(
        readResult: '{"sleepPrevention":"off","enabledPlugins":["opencode"]}',
      );
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.peekSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.off);
      expect(settings.enabledPlugins, equals(['opencode']));
      expect(api.writeCount, equals(0));
    });

    test('peekSettings returns defaults without rewriting a corrupted config', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(api: api);

      final settings = await repository.peekSettings();

      expect(settings.sleepPrevention, SleepPreventionMode.always);
      expect(api.writeCount, equals(0));
    });

    test('peekSettings reports a corrupted config on stderr, never stdout', () async {
      final api = FakeBridgeSettingsApi(readResult: '{');
      final repository = BridgeSettingsRepository(api: api);
      final stderrLines = <String>[];
      final stdoutLines = <String>[];

      await IOOverrides.runZoned(
        repository.peekSettings,
        stderr: () => _CapturingStdout(stderrLines),
        stdout: () => _CapturingStdout(stdoutLines),
      );

      expect(stderrLines, hasLength(1));
      expect(stderrLines.single, contains('invalid config at /tmp/config.json'));
      expect(stdoutLines, isEmpty, reason: 'stdout must stay machine-clean for --version/--help');
    });

    test('peekSettings logs nothing for a valid or missing config', () async {
      final stderrLines = <String>[];
      final stdoutLines = <String>[];

      await IOOverrides.runZoned(
        () async {
          await BridgeSettingsRepository(
            api: FakeBridgeSettingsApi(readResult: null),
          ).peekSettings();
          await BridgeSettingsRepository(
            api: FakeBridgeSettingsApi(readResult: '{"sleepPrevention":"off"}'),
          ).peekSettings();
        },
        stderr: () => _CapturingStdout(stderrLines),
        stdout: () => _CapturingStdout(stdoutLines),
      );

      expect(stderrLines, isEmpty);
      expect(stdoutLines, isEmpty);
    });

    test('saveSettings pretty prints JSON through the api', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(api: api);

      await repository.saveSettings(
        settings: const BridgeSettings(sleepPrevention: SleepPreventionMode.off),
      );

      expect(
        api.lastWrittenConfig,
        equals('{\n  "sleepPrevention": "off",\n  "releaseTrack": "stable"\n}'),
      );
    });

    test('updateReleaseTrack persists the track and preserves other settings', () async {
      final api = FakeBridgeSettingsApi(readResult: '{"sleepPrevention":"off"}');
      final repository = BridgeSettingsRepository(api: api);

      await repository.updateReleaseTrack(track: ReleaseTrack.internal);

      expect(
        api.lastWrittenConfig,
        equals('{\n  "sleepPrevention": "off",\n  "releaseTrack": "internal"\n}'),
      );
    });

    test('configFilePath delegates to the api', () {
      final api = FakeBridgeSettingsApi(
        readResult: null,
        configFilePath: '/tmp/custom-config.json',
      );
      final repository = BridgeSettingsRepository(api: api);

      expect(repository.configFilePath, equals('/tmp/custom-config.json'));
    });
  });
}

const _defaultJson = '{\n  "sleepPrevention": "always",\n  "releaseTrack": "stable"\n}';

/// Captures [writeln] calls; [IOOverrides] swaps it in for stdout/stderr.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  Future<String?> readConfig() async {
    return readResult;
  }

  @override
  Future<void> writeConfig(String jsonContent) async {
    lastWrittenConfig = jsonContent;
    writeCount += 1;
  }
}
