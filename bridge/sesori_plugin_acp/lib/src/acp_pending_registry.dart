import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_stdio_client.dart";

/// ACP request routing plus neutral pending lifecycle, without permission policy
/// or a responder. Each implementation owns its connection-scoped reply path.
abstract class AcpPendingRegistry<TPayload extends Object>({
  required super.emit,
  required super.logContext,
  required super.resolvePermission,
  required super.resolveQuestion,
  required super.rejectQuestion,
  required super.cancelPending,
  required super.idGenerator,
}) extends PendingPermissionRegistry<AcpServerRequest, TPayload> {
  void handleServerRequest({required AcpServerRequest request}) => handleRequest(request);

  /// No active-turn fallback may approve an ambiguously attributed request.
  void rejectAmbiguousServerRequest({required AcpServerRequest request});
}
