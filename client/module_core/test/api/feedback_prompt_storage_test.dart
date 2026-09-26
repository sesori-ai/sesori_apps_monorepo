import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _MemoryPersister() extends Fake implements PersisterRepository {
  final values = <String, String>{};

  @override
  Future<String?> readString({required StringPersistenceKey key}) async => values[key.storageKey];

  @override
  Future<void> writeString({required StringPersistenceKey key, required String value}) async {
    values[key.storageKey] = value;
  }
}

void main() {
  late _MemoryPersister persister;
  late FeedbackPromptStorage storage;

  setUp(() {
    persister = _MemoryPersister();
    storage = FeedbackPromptStorage(persister: persister);
  });

  Object? storedJson() => switch (persister.values["feedback_prompt_v1"]) {
    final String value => jsonDecode(value),
    null => null,
  };

  test("reads nothing on a device that never stored progress", () async {
    expect(await storage.read(), isNull);
  });

  test("round-trips counting progress as versioned device-scoped JSON", () async {
    final shownAt = DateTime.utc(2026, 9, 12, 8, 30);
    await storage.write(state: FeedbackPromptCounting(positiveCount: 7, lastShownAt: shownAt));

    expect(storedJson(), {
      "version": 1,
      "kind": "counting",
      "positiveCount": 7,
      "lastShownAt": "2026-09-12T08:30:00.000Z",
    });
    expect(
      await storage.read(),
      isA<FeedbackPromptCounting>()
          .having((state) => state.positiveCount, "positiveCount", 7)
          .having((state) => state.lastShownAt, "lastShownAt", shownAt),
    );
  });

  test("round-trips progress that has never been shown", () async {
    await storage.write(state: const FeedbackPromptCounting(positiveCount: 0, lastShownAt: null));

    expect(
      await storage.read(),
      isA<FeedbackPromptCounting>()
          .having((state) => state.positiveCount, "positiveCount", 0)
          .having((state) => state.lastShownAt, "lastShownAt", isNull),
    );
  });

  test("round-trips the retired state", () async {
    await storage.write(state: const FeedbackPromptRetired());

    expect(storedJson(), {"version": 1, "kind": "retired"});
    expect(await storage.read(), isA<FeedbackPromptRetired>());
  });

  for (final (name, stored) in [
    ("malformed JSON", "{"),
    ("an unknown version", jsonEncode({"version": 2, "kind": "retired"})),
    ("an unknown kind", jsonEncode({"version": 1, "kind": "snoozed"})),
    ("a negative count", jsonEncode({"version": 1, "kind": "counting", "positiveCount": -1, "lastShownAt": null})),
    ("a bad timestamp", jsonEncode({"version": 1, "kind": "counting", "positiveCount": 1, "lastShownAt": "soon"})),
  ]) {
    test("discards $name as unreadable", () async {
      persister.values["feedback_prompt_v1"] = stored;

      expect(await storage.read(), isNull);
    });
  }
}
