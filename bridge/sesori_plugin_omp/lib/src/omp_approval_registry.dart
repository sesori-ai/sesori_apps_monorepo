import "package:acp_plugin/acp_plugin.dart";

/// Oh My Pi's form elicitations carry each choice's "Other" answer in a
/// separate free-text property; this pairs the two so the client shows one
/// question with an "Other" field instead of a second step.
class OmpApprovalRegistry({
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

  /// The `ask` tool names the pair `q0`/`q0__other`; an HTML form names it
  /// `color`/`color_other`.
  @override
  String? elicitationCustomAnswerKey({required String choiceKey, required Set<String> propertyKeys}) {
    for (final candidate in ["${choiceKey}__other", "${choiceKey}_other"]) {
      if (propertyKeys.contains(candidate)) return candidate;
    }
    return null;
  }
}
