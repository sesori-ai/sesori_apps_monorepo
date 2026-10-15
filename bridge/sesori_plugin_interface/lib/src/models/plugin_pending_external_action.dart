enum PluginExternalActionPurpose() {
  authorization,
  connectorConsent,
}

enum PluginExternalActionChoice() {
  accept,
  decline,
  cancel,
}

enum PluginExternalActionReply() {
  accepted,
  alreadySettled,
  unsupportedChoice,
  unavailable,
}

/// A native session request. Destinations belong in request-scoped snapshots,
/// never in question notifications or persisted session state.
final class const PluginPendingExternalAction({
  required final String id,
  required final String sessionID,
  required final String? displaySessionId,
  required final String title,
  required final String message,
  required final String authorizationUrl,
  required final PluginExternalActionPurpose purpose,
  required final List<PluginExternalActionChoice> choices,
});
