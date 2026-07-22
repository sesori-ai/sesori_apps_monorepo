import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeConfigService', () {
    test('openConfigFile ensures settings exist, opens config file, and returns its path', () async {
      final bridgeSettingsRepository = _FakeBridgeSettingsRepository(
        configFilePath: '/tmp/custom-config.json',
      );
      final defaultEditorRepository = _FakeDefaultEditorRepository();
      final service = BridgeConfigService(
        bridgeSettingsRepository: bridgeSettingsRepository,
        defaultEditorRepository: defaultEditorRepository,
      );

      final configFilePath = await service.openConfigFile();

      expect(bridgeSettingsRepository.ensureConfigExistsCallCount, equals(1));
      expect(defaultEditorRepository.openedPaths, equals(['/tmp/custom-config.json']));
      expect(configFilePath, equals('/tmp/custom-config.json'));
    });

    test('lists known and preserved unknown disabled plugins', () async {
      final repository = _FakeBridgeSettingsRepository(
        configFilePath: '/tmp/config.json',
        settings: const BridgeSettings(
          plugins: BridgePluginSettings(disabledPluginIds: {'cursor', 'future'}),
        ),
      );
      final service = BridgeConfigService(
        bridgeSettingsRepository: repository,
        defaultEditorRepository: _FakeDefaultEditorRepository(),
      );

      final snapshot = await service.listPlugins(knownPluginIds: const ['cursor', 'opencode']);

      expect(snapshot.plugins, [
        (pluginId: 'cursor', enabled: false),
        (pluginId: 'opencode', enabled: true),
      ]);
      expect(snapshot.unknownDisabledPluginIds, ['future']);
    });

    test('rejects unknown plugin mutations before persistence', () async {
      final repository = _FakeBridgeSettingsRepository(configFilePath: '/tmp/config.json');
      final service = BridgeConfigService(
        bridgeSettingsRepository: repository,
        defaultEditorRepository: _FakeDefaultEditorRepository(),
      );

      await expectLater(
        service.setPluginEnabled(pluginId: 'typo', enabled: false, knownPluginIds: const {'opencode'}),
        throwsA(isA<UnknownPluginConfigException>()),
      );
      expect(repository.pluginUpdates, isEmpty);
    });
  });
}

class _FakeBridgeSettingsRepository implements BridgeSettingsRepository {
  _FakeBridgeSettingsRepository({
    required this.configFilePath,
    this.settings = const BridgeSettings(),
  });

  @override
  final String configFilePath;

  BridgeSettings settings;
  int ensureConfigExistsCallCount = 0;
  final List<({String pluginId, bool disabled})> pluginUpdates = [];

  @override
  BridgeSettings get currentSettings => settings;

  @override
  Future<void> ensureConfigExists() async {
    ensureConfigExistsCallCount += 1;
  }

  @override
  Future<BridgeSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings({required BridgeSettings settings}) async {
    this.settings = settings;
  }

  @override
  Future<BridgeSettings> updatePluginDisabled({required String pluginId, required bool disabled}) async {
    pluginUpdates.add((pluginId: pluginId, disabled: disabled));
    return settings = settings.copyWith(
      plugins: settings.plugins.withPluginDisabled(pluginId: pluginId, disabled: disabled),
    );
  }

  @override
  Future<void> updateReleaseTrack({required ReleaseTrack track}) async {}

  @override
  Future<void> updateYolo({required bool enabled}) async {}
}

class _FakeDefaultEditorRepository implements DefaultEditorRepository {
  final List<String> openedPaths = [];

  @override
  Future<void> openFile(String filePath) async {
    openedPaths.add(filePath);
  }
}
