import "models/plugin_pending_external_action.dart";

/// Optional support for native session requests awaiting an external action.
/// Implementations keep the request in their existing pending interaction owner.
abstract interface class SessionExternalActionsPluginApi() {
  Future<List<PluginPendingExternalAction>> getPendingExternalActions({required String sessionId});

  Future<PluginExternalActionReply> replyToExternalAction({
    required String requestId,
    required String sessionId,
    required PluginExternalActionChoice choice,
  });
}
