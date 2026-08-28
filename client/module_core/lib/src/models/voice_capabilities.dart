sealed class const VoiceCapabilitiesDiscoveryOutcome();

final class const VoiceCapabilitiesAvailable({required final VoiceCapabilities capabilities})
    extends VoiceCapabilitiesDiscoveryOutcome;

final class const VoiceCapabilitiesAsyncFallback() extends VoiceCapabilitiesDiscoveryOutcome;

final class const VoiceCapabilitiesContractFailure({required final String reason})
    extends VoiceCapabilitiesDiscoveryOutcome;

final class const VoiceCapabilities({
  required final bool realtimeEnabled,
  required final bool supportsProtocol1,
}) {
  bool get canUseRealtimeProtocol1 => realtimeEnabled && supportsProtocol1;
}
