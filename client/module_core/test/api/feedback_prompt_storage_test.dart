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

  test("round-trips per-session counting progress as device-scoped JSON", () async {
    final shownAt = DateTime.utc(2026, 9, 12, 8, 30);
    await storage.write(
      state: FeedbackPromptCounting(pointsBySession: const {"ses-a": 2, "ses-b": 1}, lastShownAt: shownAt),
    );

    expect(storedJson(), {
      "kind": "counting",
      "pointsBySession": {"ses-a": 2, "ses-b": 1},
      "lastShownAt": "2026-09-12T08:30:00.000Z",
    });
    expect(
      await storage.read(),
      FeedbackPromptCounting(pointsBySession: const {"ses-a": 2, "ses-b": 1}, lastShownAt: shownAt),
    );
  });

  test("round-trips progress that has never been shown", () async {
    await storage.write(state: const FeedbackPromptCounting(pointsBySession: {}, lastShownAt: null));

    expect(await storage.read(), const FeedbackPromptCounting(pointsBySession: {}, lastShownAt: null));
  });

  test("round-trips the retired state", () async {
    await storage.write(state: const FeedbackPromptRetired());

    expect(storedJson(), {"kind": "retired"});
    expect(await storage.read(), const FeedbackPromptRetired());
  });

  test("reads progress stored before per-session points with no points and its last showing", () async {
    persister.values["feedback_prompt_v1"] = jsonEncode({
      "version": 1,
      "kind": "counting",
      "positiveCount": 4,
      "lastShownAt": "2026-09-12T08:30:00.000Z",
    });

    expect(
      await storage.read(),
      FeedbackPromptCounting(pointsBySession: const {}, lastShownAt: DateTime.utc(2026, 9, 12, 8, 30)),
    );
  });

  test("keeps a Yes stored before per-session points", () async {
    persister.values["feedback_prompt_v1"] = jsonEncode({"version": 1, "kind": "retired"});

    expect(await storage.read(), const FeedbackPromptRetired());
  });

  for (final (name, stored) in [
    ("malformed JSON", "{"),
    ("an unknown kind", jsonEncode({"kind": "snoozed"})),
    (
      "non-numeric points",
      jsonEncode({
        "kind": "counting",
        "pointsBySession": {"ses-a": "two"},
      }),
    ),
    ("a bad timestamp", jsonEncode({"kind": "counting", "pointsBySession": <String, int>{}, "lastShownAt": "soon"})),
  ]) {
    test("discards $name as unreadable", () async {
      persister.values["feedback_prompt_v1"] = stored;

      expect(await storage.read(), isNull);
    });
  }
}
