/// Plugin identity used when decoding payloads from peers that predate plugin attribution.
///
/// Those peers could only communicate with OpenCode, so their missing identity
/// is attributed directly instead of introducing an unresolved wire value.
const String legacyMissingPluginId = "opencode";
