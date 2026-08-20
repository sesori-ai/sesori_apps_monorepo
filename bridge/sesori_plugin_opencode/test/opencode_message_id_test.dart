import "package:opencode_plugin/src/opencode_message_id.dart";
import "package:test/test.dart";

void main() {
  group("generateOpenCodeMessageId", () {
    test("matches OpenCode's own message id shape", () {
      final id = generateOpenCodeMessageId();

      // `msg_` plus OpenCode's 26-character body: 12 hex characters of
      // encoded time followed by 14 random base62 characters.
      expect(id, matches(RegExp(r"^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$")));
    });

    test("keeps ids sortable and unique across a same-millisecond burst", () {
      final ids = List.generate(50, (_) => generateOpenCodeMessageId());

      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, orderedEquals([...ids]..sort()));
    });
  });
}
