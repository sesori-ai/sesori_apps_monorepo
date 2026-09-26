import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockFeedbackPromptConfigApi() extends Mock implements FeedbackPromptConfigApi;

class _MockFeedbackPromptStorage() extends Mock implements FeedbackPromptStorage;

void main() {
  late _MockFeedbackPromptConfigApi configApi;
  late _MockFeedbackPromptStorage storage;
  late FeedbackPromptRepository repository;

  setUp(() {
    configApi = _MockFeedbackPromptConfigApi();
    storage = _MockFeedbackPromptStorage();
    repository = FeedbackPromptRepository(configApi: configApi, storage: storage);
  });

  void answerValues({required int? interactionThreshold, required int? cooldownDays}) =>
      when(configApi.fetchValues).thenAnswer(
        (_) async => (interactionThreshold: interactionThreshold, cooldownDays: cooldownDays),
      );

  test("uses the remote threshold and cooldown", () async {
    answerValues(interactionThreshold: 2, cooldownDays: 1);

    final config = await repository.readConfig();

    expect(config.interactionThreshold, 2);
    expect(config.cooldown, const Duration(days: 1));
  });

  for (final (name, value) in [("missing", null), ("zero", 0), ("negative", -3)]) {
    test("falls back to 10 interactions and 14 days when both values are $name", () async {
      answerValues(interactionThreshold: value, cooldownDays: value);

      final config = await repository.readConfig();

      expect(config.interactionThreshold, 10);
      expect(config.cooldown, const Duration(days: 14));
    });
  }

  test("falls back per value", () async {
    answerValues(interactionThreshold: 0, cooldownDays: 30);

    final config = await repository.readConfig();

    expect(config.interactionThreshold, 10);
    expect(config.cooldown, const Duration(days: 30));
  });

  test("a device without stored progress starts counting from zero, never shown", () async {
    when(storage.read).thenAnswer((_) async => null);

    expect(
      await repository.readState(),
      isA<FeedbackPromptCounting>()
          .having((state) => state.positiveCount, "positiveCount", 0)
          .having((state) => state.lastShownAt, "lastShownAt", isNull),
    );
  });
}
