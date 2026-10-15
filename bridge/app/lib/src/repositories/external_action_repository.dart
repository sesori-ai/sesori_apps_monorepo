import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../runtime/plugin_runtime.dart";
import "mappers/plugin_external_action_mapper.dart";
import "models/session_operation.dart";
import "pending_interaction_support.dart";

/// Native pending interactions, scoped through the bridge's durable binding.
class ExternalActionRepository({
  required final PluginRuntime _runtime,
  required final PendingInteractionSupport _pendingSupport,
}) {
  Future<List<PendingExternalAction>> getPending({required String sessionId}) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getPendingExternalActions,
    );
    return await _runtime.useIfActive(
          pluginId: binding.pluginId,
          operation: SessionOperation.getPendingExternalActions,
          body: (plugin, _) async {
            final api = switch (plugin) {
              final SessionExternalActionsPluginApi api => api,
              _ => null,
            };
            if (api == null) return const <PendingExternalAction>[];
            final tombstones = await _pendingSupport.readPendingTombstones(
              plugin: plugin,
              backendSessionId: binding.backendSessionId,
            );
            if (tombstones == null) return const <PendingExternalAction>[];
            final actions = <PluginPendingExternalAction>[
              for (final action in await api.getPendingExternalActions(sessionId: binding.backendSessionId))
                if (_pendingSupport.isVisible(
                  sessionId: action.sessionID,
                  displaySessionId: action.displaySessionId,
                  tombstones: tombstones,
                ))
                  action,
            ];
            return await _pendingSupport.mapExternalActions(pluginId: binding.pluginId, actions: actions);
          },
        ) ??
        const [];
  }

  Future<ExternalActionReplyResult> reply({required ReplyToExternalActionRequest request}) async {
    final choice = request.choice.toPlugin();
    if (choice == null) return const ExternalActionUnsupportedChoice();
    final binding = await _pendingSupport.requireBinding(
      sessionId: request.sessionId,
      operation: SessionOperation.replyToExternalAction,
    );
    return await _runtime.useIfActive(
          pluginId: binding.pluginId,
          operation: SessionOperation.replyToExternalAction,
          body: (plugin, _) async {
            final api = switch (plugin) {
              final SessionExternalActionsPluginApi api => api,
              _ => null,
            };
            if (api == null) return const ExternalActionUnsupportedChoice();
            final actions = await api.getPendingExternalActions(sessionId: binding.backendSessionId);
            await _pendingSupport.throwIfMutationTargetTombstoned(
              interactionId: request.requestId,
              backendSessionId: binding.backendSessionId,
              operation: SessionOperation.replyToExternalAction,
              plugin: plugin,
              readPending: () async => [
                for (final action in actions)
                  (id: action.id, sessionID: action.sessionID, displaySessionId: action.displaySessionId),
              ],
            );
            for (final action in actions) {
              if (action.id != request.requestId) continue;
              if (!action.choices.contains(choice)) return const ExternalActionUnsupportedChoice();
              break;
            }
            return switch (await api.replyToExternalAction(
              requestId: request.requestId,
              sessionId: binding.backendSessionId,
              choice: choice,
            )) {
              PluginExternalActionReply.accepted => const ExternalActionReplyAccepted(),
              PluginExternalActionReply.alreadySettled => const ExternalActionAlreadySettled(),
              PluginExternalActionReply.unsupportedChoice => const ExternalActionUnsupportedChoice(),
              PluginExternalActionReply.unavailable => _replyUnavailable(
                requestId: request.requestId,
                sessionId: binding.backendSessionId,
              ),
            };
          },
        ) ??
        const ExternalActionAlreadySettled();
  }

  Never _replyUnavailable({required String requestId, required String sessionId}) {
    Log.w("Native external-action response unavailable for $requestId in $sessionId");
    throw PluginOperationException(
      SessionOperation.replyToExternalAction.name,
      statusCode: 503,
      message: "native external-action response is unavailable",
    );
  }
}
