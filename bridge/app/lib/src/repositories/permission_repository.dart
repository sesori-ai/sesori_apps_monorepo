import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/session_dao.dart";
import "../runtime/plugin_runtime.dart";
import "models/session_operation.dart";
import "pending_interaction_support.dart";

/// Layer 2 repository wrapping [plugin_interface.BridgePlugin] for permission operations.
///
/// Delegates directly to the plugin — mandatory even though it's a thin
/// wrapper, because [plugin_interface.BridgePlugin] is Layer 1 and handlers
/// must not call it directly.
///
/// Also maps the wire-format [PermissionReply] (from `sesori_shared`) to the
/// plugin-contract [plugin_interface.PermissionReply] to keep the two enums
/// decoupled.
class PermissionRepository({required final PluginRuntime _runtime, required final SessionDao _sessionDao}) {
  late final PendingInteractionSupport _pendingSupport = PendingInteractionSupport(sessionDao: _sessionDao);

  /// Pending permissions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingPermission>> getPendingPermissions({required String sessionId}) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getPendingPermissions,
    );
    // Deliberately does not start a stopped backend — see the matching note in
    // QuestionRepository. A stopped backend holds no pending permissions, so
    // waking it to ask could only answer "none".
    final pending = await _runtime.useIfActive(
      pluginId: binding.pluginId,
      operation: SessionOperation.getPendingPermissions,
      body: (plugin, _) async {
        final tombstones = await _pendingSupport.readPendingTombstones(
          plugin: plugin,
          backendSessionId: binding.backendSessionId,
        );
        if (tombstones == null) return const <PendingPermission>[];
        final permissions = await plugin.getPendingPermissions(sessionId: binding.backendSessionId);
        return await _pendingSupport.mapPermissions(
          pluginId: plugin.id,
          permissions: [
            for (final permission in permissions)
              if (_isVisible(permission, tombstones)) permission,
          ],
        );
      },
    );
    // Null means the backend is not running, which is indistinguishable from
    // "it has none" for this question.
    return pending ?? const [];
  }

  bool _isVisible(PluginPendingPermission permission, Set<String> tombstoned) => _pendingSupport.isVisible(
    sessionId: permission.sessionID,
    displaySessionId: permission.displaySessionId,
    tombstones: tombstoned,
  );

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.replyToPermission,
    );
    return await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.replyToPermission,
      body: (plugin) async {
        await _pendingSupport.throwIfMutationTargetTombstoned(
          interactionId: requestId,
          backendSessionId: binding.backendSessionId,
          operation: SessionOperation.replyToPermission,
          plugin: plugin,
          readPending: () async => [
            for (final permission in await plugin.getPendingPermissions(sessionId: binding.backendSessionId))
              (id: permission.id, sessionID: permission.sessionID, displaySessionId: permission.displaySessionId),
          ],
        );
        return await plugin.replyToPermission(
          requestId: requestId,
          sessionId: binding.backendSessionId,
          reply: _toPluginReply(reply),
        );
      },
    );
  }

  static PluginPermissionReply _toPluginReply(PermissionReply reply) => switch (reply) {
    .once => .once,
    .always => .always,
    .reject => .reject,
  };
}
