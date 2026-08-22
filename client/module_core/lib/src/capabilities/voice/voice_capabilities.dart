// ignore_for_file: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters

sealed class const VoiceCapabilitiesDiscoveryResult();

final class const VoiceCapabilitiesAvailable({required final VoiceCapabilities capabilities})
    extends VoiceCapabilitiesDiscoveryResult;

final class const VoiceCapabilitiesAsyncFallback() extends VoiceCapabilitiesDiscoveryResult;

final class const VoiceCapabilitiesContractFailure({required final String reason})
    extends VoiceCapabilitiesDiscoveryResult;

final class const VoiceCapabilities({required final bool realtimeEnabled, required final List<int> protocolVersions}) {
  bool get supportsProtocol1 => protocolVersions.contains(1);
  bool get canUseRealtimeProtocol1 => realtimeEnabled && supportsProtocol1;

  static VoiceCapabilities parse(Object? json) {
    final root = _expectExactMap(json, {"realtime"});
    final realtime = _expectExactMap(root["realtime"], {"enabled", "protocolVersions"});
    final enabled = realtime["enabled"];
    final versions = realtime["protocolVersions"];
    if (enabled is! bool) {
      throw const FormatException("Voice capabilities realtime.enabled must be boolean");
    }
    if (versions is! List<Object?> || versions.isEmpty) {
      throw const FormatException("Voice capabilities realtime.protocolVersions must be a non-empty list");
    }
    final parsedVersions = <int>[];
    for (final version in versions) {
      if (version is! int || version < 1) {
        throw const FormatException("Voice capabilities protocol version must be a positive integer");
      }
      parsedVersions.add(version);
    }
    return VoiceCapabilities(realtimeEnabled: enabled, protocolVersions: List.unmodifiable(parsedVersions));
  }
}

Map<String, Object?> _expectExactMap(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?>) {
    throw const FormatException("Expected JSON object");
  }
  if (value.length != keys.length || !value.keys.every(keys.contains)) {
    throw FormatException("Unexpected JSON keys: ${value.keys.join(",")}");
  }
  return value;
}
