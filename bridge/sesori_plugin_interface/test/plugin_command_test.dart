import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("PluginCommandInvocationContext round-trips JSON", () {
    const context = PluginCommandInvocationContext(
      invocationId: "invocation-1",
      name: "compact",
      arguments: "focus on command handling",
      acceptedAt: 1784192400000,
      backendMessageId: "message-1",
    );

    expect(PluginCommandInvocationContext.fromJson(context.toJson()), context);
  });

  test("PluginCommandDispatch round-trips a missing backend message id", () {
    const dispatch = PluginCommandDispatch(backendMessageId: null);

    expect(dispatch.toJson(), isNot(contains("backendMessageId")));
    expect(PluginCommandDispatch.fromJson(dispatch.toJson()), dispatch);
  });

  test("PluginMessage.command serializes command result metadata", () {
    const message = PluginMessageWithParts(
      info: PluginMessage.command(
        id: "message-1",
        sessionID: "session-1",
        name: "compact",
        arguments: null,
        origin: PluginCommandOrigin.automatic,
        invocationId: "invocation-1",
        time: PluginMessageTime(created: 1784192400000, completed: null),
      ),
      parts: <PluginMessagePart>[],
    );

    expect(message.toJson(), {
      "info": {
        "id": "message-1",
        "sessionID": "session-1",
        "name": "compact",
        "origin": "automatic",
        "invocationId": "invocation-1",
        "time": {"created": 1784192400000},
        "role": "command",
      },
      "parts": <Object>[],
    });
  });
}
