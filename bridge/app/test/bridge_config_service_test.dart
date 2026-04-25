import 'package:sesori_bridge/src/foundation/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:sesori_bridge/src/services/bridge_config_service.dart';
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

      expect(bridgeSettingsRepository.loadSettingsCallCount, equals(1));
      expect(defaultEditorRepository.openedPaths, equals(['/tmp/custom-config.json']));
      expect(configFilePath, equals('/tmp/custom-config.json'));
    });
  });
}

class _FakeBridgeSettingsRepository implements BridgeSettingsRepository {
  _FakeBridgeSettingsRepository({required this.configFilePath});

  @override
  final String configFilePath;

  int loadSettingsCallCount = 0;

  @override
  Future<BridgeSettings> loadSettings() async {
    loadSettingsCallCount += 1;
    return const BridgeSettings();
  }

  @override
  Future<void> saveSettings({required BridgeSettings settings}) async {}
}

class _FakeDefaultEditorRepository implements DefaultEditorRepository {
  final List<String> openedPaths = [];

  @override
  Future<void> openFile(String filePath) async {
    openedPaths.add(filePath);
  }
}
