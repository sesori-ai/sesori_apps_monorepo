import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/foundation/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
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

    test('saveSettings pretty prints JSON through the api', () async {
      final api = FakeBridgeSettingsApi(readResult: null);
      final repository = BridgeSettingsRepository(api: api);

      await repository.saveSettings(
        settings: const BridgeSettings(sleepPrevention: SleepPreventionMode.off),
      );

      expect(
        api.lastWrittenConfig,
        equals('{\n  "sleepPrevention": "off"\n}'),
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

const _defaultJson = '{\n  "sleepPrevention": "always"\n}';

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
