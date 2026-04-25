import '../repositories/bridge_settings_repository.dart';
import '../repositories/default_editor_repository.dart';

class BridgeConfigService {
  BridgeConfigService({
    required BridgeSettingsRepository bridgeSettingsRepository,
    required DefaultEditorRepository defaultEditorRepository,
  }) : _bridgeSettingsRepository = bridgeSettingsRepository,
       _defaultEditorRepository = defaultEditorRepository;

  final BridgeSettingsRepository _bridgeSettingsRepository;
  final DefaultEditorRepository _defaultEditorRepository;

  Future<String> openConfigFile() async {
    await _bridgeSettingsRepository.loadSettings();
    final configFilePath = _bridgeSettingsRepository.configFilePath;
    await _defaultEditorRepository.openFile(configFilePath);
    return configFilePath;
  }
}
