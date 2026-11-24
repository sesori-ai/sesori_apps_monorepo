import "package:acp_plugin/acp_plugin.dart";

/// Copilot's `ask_user` form tells the model "The user can also provide a
/// freeform answer" for every choice field, so the model leaves out an
/// "Other" choice. This lets each choice question take free text, which
/// Copilot accepts as the field's own value.
class CopilotApprovalRegistry({
  required AcpStdioClient client,
  required super.emit,
  required super.idGenerator,
  required super.activeSessionResolver,
}) extends AcpApprovalRegistry {
  this
    : super(
        respond: (id, result) => client.respondToServerRequest(id: id, result: result),
        respondError: (id, code, message) =>
            client.respondToServerRequestWithError(id: id, code: code, message: message),
      );

  @override
  String? elicitationCustomAnswerKey({required String choiceKey, required Set<String> propertyKeys}) => choiceKey;
}
