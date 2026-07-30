import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/services/draft_store.dart";
import "package:test/test.dart";

void main() {
  group("DraftStore", () {
    late DraftStore store;

    setUp(() => store = DraftStore());

    test("read returns null when no draft is saved", () {
      expect(store.read(key: "s1"), isNull);
    });

    test("write then read round-trips text and input mode per key", () {
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "hello", inputMode: AnalyticsInputMode.voiceAssisted),
      );
      store.write(
        key: "s2",
        draft: const ComposerDraft(text: "world", inputMode: AnalyticsInputMode.typed),
      );
      expect(store.read(key: "s1"), const ComposerDraft(text: "hello", inputMode: AnalyticsInputMode.voiceAssisted));
      expect(store.read(key: "s2"), const ComposerDraft(text: "world", inputMode: AnalyticsInputMode.typed));
    });

    test("write overwrites the previous draft for a key", () {
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "first", inputMode: AnalyticsInputMode.voiceAssisted),
      );
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "second", inputMode: AnalyticsInputMode.typed),
      );
      expect(store.read(key: "s1"), const ComposerDraft(text: "second", inputMode: AnalyticsInputMode.typed));
    });

    test("writing empty or whitespace-only text clears the draft", () {
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "draft", inputMode: AnalyticsInputMode.voiceAssisted),
      );
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "   \n ", inputMode: AnalyticsInputMode.voiceAssisted),
      );
      expect(store.read(key: "s1"), isNull);

      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "draft", inputMode: AnalyticsInputMode.voiceAssisted),
      );
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "", inputMode: AnalyticsInputMode.voiceAssisted),
      );
      expect(store.read(key: "s1"), isNull);
    });

    test("clear removes a saved draft", () {
      store.write(
        key: "s1",
        draft: const ComposerDraft(text: "draft", inputMode: AnalyticsInputMode.typed),
      );
      store.clear(key: "s1");
      expect(store.read(key: "s1"), isNull);
    });

    test("preserves internal whitespace of a non-blank draft", () {
      store.write(
        key: "s1",
        draft: const ComposerDraft(
          text: "  leading and trailing  ",
          inputMode: AnalyticsInputMode.voiceAssisted,
        ),
      );
      expect(
        store.read(key: "s1"),
        const ComposerDraft(
          text: "  leading and trailing  ",
          inputMode: AnalyticsInputMode.voiceAssisted,
        ),
      );
    });
  });
}
