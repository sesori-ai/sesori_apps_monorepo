import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("MessagePartTool.kind", () {
    // ignore: no_slop_linter/prefer_specific_type, JSON fixture
    MessagePartTool parse(Map<String, dynamic> extra) => MessagePart.fromJson({
      "type": "tool",
      "id": "part-1",
      "sessionID": "session-1",
      "messageID": "message-1",
      "tool": "Read",
      ...extra,
    }) as MessagePartTool;

    test("reads an older bridge payload without a kind as unknown", () {
      expect(parse({}).kind, ToolKind.unknown);
    });

    test("reads a kind this app does not know as unknown", () {
      expect(parse({"kind": "browse"}).kind, ToolKind.unknown);
    });

    test("round-trips a known kind", () {
      final part = parse({"kind": "edit"});

      expect(part.kind, ToolKind.edit);
      expect(MessagePart.fromJson(part.toJson()), part);
    });
  });
}
