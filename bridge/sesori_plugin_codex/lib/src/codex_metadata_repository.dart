import "codex_config_reader.dart";

/// Maps Codex's global configuration metadata.
class CodexMetadataRepository({
  required final CodexConfigReader _configReader,
}) {
  CodexConfigDefaults readConfigDefaults() => _configReader.readDefaults();
}
