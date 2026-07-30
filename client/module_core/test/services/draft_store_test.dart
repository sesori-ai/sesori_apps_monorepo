import "package:sesori_dart_core/src/services/draft_store.dart";
import "package:test/test.dart";

void main() {
  group("DraftStore", () {
    late DraftStore store;

    setUp(() => store = DraftStore());

    test("read returns null when no draft is saved", () {
      expect(store.read(key: "s1"), isNull);
    });

    test("write then read round-trips text and voice origins per key", () {
      store.write(
        key: "s1",
        draft: _voiceDraft("hello"),
      );
      store.write(
        key: "s2",
        draft: _typedDraft("world"),
      );
      expect(store.read(key: "s1"), _voiceDraft("hello"));
      expect(store.read(key: "s2"), _typedDraft("world"));
    });

    test("write overwrites the previous draft for a key", () {
      store.write(
        key: "s1",
        draft: _voiceDraft("first"),
      );
      store.write(
        key: "s1",
        draft: _typedDraft("second"),
      );
      expect(store.read(key: "s1"), _typedDraft("second"));
    });

    test("writing empty or whitespace-only text clears the draft", () {
      store.write(
        key: "s1",
        draft: _voiceDraft("draft"),
      );
      store.write(
        key: "s1",
        draft: _voiceDraft("   \n "),
      );
      expect(store.read(key: "s1"), isNull);

      store.write(
        key: "s1",
        draft: _voiceDraft("draft"),
      );
      store.write(
        key: "s1",
        draft: _voiceDraft(""),
      );
      expect(store.read(key: "s1"), isNull);
    });

    test("clear removes a saved draft", () {
      store.write(
        key: "s1",
        draft: _typedDraft("draft"),
      );
      store.clear(key: "s1");
      expect(store.read(key: "s1"), isNull);
    });

    test("preserves internal whitespace of a non-blank draft", () {
      store.write(
        key: "s1",
        draft: _voiceDraft("  leading and trailing  "),
      );
      expect(
        store.read(key: "s1"),
        _voiceDraft("  leading and trailing  "),
      );
    });
  });
}

ComposerDraft _typedDraft(String text) => ComposerDraft(
  text: text,
  voiceOriginByCodeUnit: List.filled(text.length, false),
);

ComposerDraft _voiceDraft(String text) => ComposerDraft(
  text: text,
  voiceOriginByCodeUnit: List.filled(text.length, true),
);
