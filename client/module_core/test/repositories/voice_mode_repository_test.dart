import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockVoiceModeConfigApi() extends Mock implements VoiceModeConfigApi;

void main() {
  late _MockVoiceModeConfigApi configApi;
  late VoiceModeRepository repository;

  setUp(() {
    configApi = _MockVoiceModeConfigApi();
    repository = VoiceModeRepository(configApi: configApi);
  });

  void answerValues({required bool liveEnabled, required String? presentation}) => when(
    configApi.fetchValues,
  ).thenAnswer((_) async => (liveEnabled: liveEnabled, presentation: presentation));

  Matcher isLive({required VoiceLivePresentation presentation}) =>
      isA<VoiceModeLive>().having((mode) => mode.presentation, "presentation", presentation);

  group("parsing", () {
    test("live with panel gives the panel", () async {
      answerValues(liveEnabled: true, presentation: "panel");

      await repository.load();

      expect(repository.mode, isLive(presentation: VoiceLivePresentation.panel));
    });

    for (final (name, value) in [("focus", "focus"), ("missing", null), ("unknown", "sideways"), ("cased", "Panel")]) {
      test("live with a $name presentation gives focus", () async {
        answerValues(liveEnabled: true, presentation: value);

        await repository.load();

        expect(repository.mode, isLive(presentation: VoiceLivePresentation.focus));
      });
    }

    for (final value in ["panel", "focus", null]) {
      test("live off gives after-recording with a presentation of $value", () async {
        answerValues(liveEnabled: false, presentation: value);

        await repository.load();

        expect(repository.mode, isA<VoiceModeAfterRecording>());
      });
    }
  });

  group("caching", () {
    test("reports after-recording before any load", () {
      expect(repository.mode, isA<VoiceModeAfterRecording>());
      verifyNever(configApi.fetchValues);
    });

    test("reports after-recording while the first load is in flight", () async {
      final values = Completer<VoiceModeConfigValues>();
      when(configApi.fetchValues).thenAnswer((_) => values.future);

      final load = repository.load();

      expect(repository.mode, isA<VoiceModeAfterRecording>());

      values.complete((liveEnabled: true, presentation: null));
      await load;

      expect(repository.mode, isLive(presentation: VoiceLivePresentation.focus));
    });

    test("keeps the loaded value without fetching again", () async {
      answerValues(liveEnabled: true, presentation: "panel");

      await repository.load();

      expect(repository.mode, isLive(presentation: VoiceLivePresentation.panel));
      verify(configApi.fetchValues).called(1);
    });

    test("a later load replaces the value", () async {
      answerValues(liveEnabled: true, presentation: "panel");
      await repository.load();

      answerValues(liveEnabled: false, presentation: null);
      await repository.load();

      expect(repository.mode, isA<VoiceModeAfterRecording>());
    });

    test("a failed load reports its error and keeps the last value", () async {
      answerValues(liveEnabled: true, presentation: "panel");
      await repository.load();

      when(configApi.fetchValues).thenThrow(StateError("offline"));

      await expectLater(repository.load(), throwsStateError);
      expect(repository.mode, isLive(presentation: VoiceLivePresentation.panel));
    });
  });
}
