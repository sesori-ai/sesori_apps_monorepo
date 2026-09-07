import "package:acp_plugin/acp_plugin.dart";

import "models/antigravity_permission_response_dto.dart";

/// One live ACP connection. Every permission/question resolution returns here.
class AntigravityInteractionRepository({required final AcpStdioClient _client}) {
  // ignore: no_slop_linter/prefer_specific_type, preserve opaque ACP string/integer request identity
  void select({required Object requestId, required String optionId}) => _reply(
    requestId: requestId,
    outcome: AntigravityPermissionOutcomeDto.selected(optionId: optionId),
  );

  // ignore: no_slop_linter/prefer_specific_type, preserve opaque ACP string/integer request identity
  void cancel({required Object requestId}) =>
      _reply(requestId: requestId, outcome: const AntigravityPermissionOutcomeDto.cancelled());

  // ignore: no_slop_linter/prefer_specific_type, preserve opaque ACP string/integer request identity
  void rejectAmbiguous({required Object requestId}) => _client.respondToServerRequestWithError(
    id: requestId,
    code: -32602,
    message: "Ambiguous Antigravity tool-call session attribution",
  );

  // ignore: no_slop_linter/prefer_specific_type, preserve opaque ACP string/integer request identity
  void unsupported({required Object requestId}) => _client.respondToServerRequestWithError(
    id: requestId,
    code: -32601,
    message: "Antigravity request method is not supported",
  );

  // ignore: no_slop_linter/prefer_specific_type, preserve opaque ACP string/integer request identity
  void _reply({required Object requestId, required AntigravityPermissionOutcomeDto outcome}) =>
      _client.respondToServerRequest(
        id: requestId,
        result: AntigravityPermissionResponseDto(outcome: outcome).toJson(),
      );
}
