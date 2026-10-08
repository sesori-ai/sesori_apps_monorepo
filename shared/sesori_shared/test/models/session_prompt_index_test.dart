import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("index entries carry their kind and omit absent fields on the wire", () {
    const response = SessionPromptIndexResponse(
      entries: [
        SessionPromptIndexEntry.opener(messageId: "u1", seq: 3, number: 1, createdAt: 10, preview: "Fix it"),
        SessionPromptIndexEntry.followUp(
          messageId: "u2",
          seq: 5,
          number: 2,
          createdAt: null,
          preview: null,
          openerMessageId: "u1",
        ),
      ],
    );

    final json = jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>;

    expect(json, {
      "entries": [
        {"kind": "opener", "messageId": "u1", "seq": 3, "number": 1, "createdAt": 10, "preview": "Fix it"},
        {"kind": "followUp", "messageId": "u2", "seq": 5, "number": 2, "openerMessageId": "u1"},
      ],
    });
    expect(SessionPromptIndexResponse.fromJson(json), response);
  });
}
