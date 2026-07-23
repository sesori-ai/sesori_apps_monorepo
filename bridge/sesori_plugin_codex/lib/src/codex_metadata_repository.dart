import "codex_config_reader.dart";

/// Maps Codex's global configuration metadata.
class CodexMetadataRepository {
  CodexMetadataRepository({
    required CodexConfigReader configReader,
  }) : _configReader = configReader;

  final CodexConfigReader _configReader;

  CodexConfigDefaults readConfigDefaults() => _configReader.readDefaults();
}
