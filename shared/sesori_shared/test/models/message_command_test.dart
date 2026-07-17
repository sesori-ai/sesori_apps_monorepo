import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("Message.user defaults command metadata to null", () {
    const message = Message.user(
      id: "message-1",
      sessionID: "session-1",
      agent: null,
      time: null,
    );

    expect(message, isA<MessageUser>().having((value) => value.command, "command", isNull));
    expect(message.toJson(), {
      "id": "message-1",
      "sessionID": "session-1",
      "role": "user",
    });
    expect(Message.fromJson(message.toJson()), message);
  });

  test("Message.user round-trips command metadata", () {
    const message = Message.user(
      id: "message-1",
      sessionID: "session-1",
      agent: null,
      time: MessageTime(created: 1784192400000, completed: null),
      command: CommandMessageInfo(
        name: "compact",
        arguments: "focus on command handling",
        origin: CommandOrigin.manual,
        displayPartID: "part-1",
      ),
    );

    expect(Message.fromJson(message.toJson()), message);
  });

  test("CommandMessageInfo maps unrecognized origins to unknown", () {
    final command = CommandMessageInfo.fromJson({
      "name": "compact",
      "origin": "future-origin",
      "displayPartID": "part-1",
    });

    expect(command.origin, CommandOrigin.unknown);
    expect(command.arguments, isNull);
  });
}
