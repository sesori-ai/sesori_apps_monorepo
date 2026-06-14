import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/services/draft_store.dart";

void main() {
  group("DraftStore", () {
    late DraftStore store;

    setUp(() => store = DraftStore());

    test("read returns empty string when no draft saved", () {
      expect(store.read("s1"), "");
    });

    test("write then read round-trips per key", () {
      store.write("s1", "hello");
      store.write("s2", "world");
      expect(store.read("s1"), "hello");
      expect(store.read("s2"), "world");
    });

    test("write overwrites the previous draft for a key", () {
      store.write("s1", "first");
      store.write("s1", "second");
      expect(store.read("s1"), "second");
    });

    test("writing empty or whitespace-only text clears the draft", () {
      store.write("s1", "draft");
      store.write("s1", "   \n ");
      expect(store.read("s1"), "");

      store.write("s1", "draft");
      store.write("s1", "");
      expect(store.read("s1"), "");
    });

    test("clear removes a saved draft", () {
      store.write("s1", "draft");
      store.clear("s1");
      expect(store.read("s1"), "");
    });

    test("preserves internal whitespace of a non-blank draft", () {
      store.write("s1", "  leading and trailing  ");
      expect(store.read("s1"), "  leading and trailing  ");
    });
  });
}
