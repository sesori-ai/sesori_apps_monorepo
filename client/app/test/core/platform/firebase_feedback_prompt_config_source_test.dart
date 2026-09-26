import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_feedback_prompt_config_source.dart";

class _MockFirebaseRemoteConfig() extends Mock implements FirebaseRemoteConfig;

void main() {
  late _MockFirebaseRemoteConfig remoteConfig;
  late FirebaseFeedbackPromptConfigSource source;

  setUpAll(() {
    registerFallbackValue(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 12),
      ),
    );
  });

  setUp(() {
    remoteConfig = _MockFirebaseRemoteConfig();
    source = FirebaseFeedbackPromptConfigSource(remoteConfig: remoteConfig);
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.getInt(FirebaseFeedbackPromptConfigSource.interactionThresholdKey)).thenReturn(2);
    when(() => remoteConfig.getInt(FirebaseFeedbackPromptConfigSource.cooldownDaysKey)).thenReturn(1);
  });

  test("fetches with a short timeout, then reads the activated values", () async {
    expect(await source.fetchValues(), (interactionThreshold: 2, cooldownDays: 1));

    final settings = verify(() => remoteConfig.setConfigSettings(captureAny())).captured.single as RemoteConfigSettings;
    expect(settings.fetchTimeout, const Duration(seconds: 3));
    verifyInOrder([
      () => remoteConfig.fetchAndActivate(),
      () => remoteConfig.getInt(FirebaseFeedbackPromptConfigSource.interactionThresholdKey),
      () => remoteConfig.getInt(FirebaseFeedbackPromptConfigSource.cooldownDaysKey),
    ]);
  });

  test("reads the values activated on an earlier launch when the fetch fails", () async {
    when(() => remoteConfig.fetchAndActivate()).thenThrow(StateError("offline"));

    expect(await source.fetchValues(), (interactionThreshold: 2, cooldownDays: 1));
  });
}
