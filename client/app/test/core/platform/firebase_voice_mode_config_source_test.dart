import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_remote_config_client.dart";
import "package:sesori_mobile/core/platform/firebase_voice_mode_config_source.dart";
import "package:sesori_mobile/core/platform/remote_config_flags.dart";

class _MockFirebaseRemoteConfig() extends Mock implements FirebaseRemoteConfig;

void main() {
  late _MockFirebaseRemoteConfig remoteConfig;
  late FirebaseVoiceModeConfigSource source;

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
    source = FirebaseVoiceModeConfigSource(
      remoteConfigClient: FirebaseRemoteConfigClient(remoteConfig: remoteConfig),
    );
    when(() => remoteConfig.setDefaults(any())).thenAnswer((_) async {});
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.getBool(BoolRemoteConfig.voiceLiveEnabled.key)).thenReturn(true);
  });

  test("uses the agreed parameter key", () {
    expect(BoolRemoteConfig.voiceLiveEnabled.key, "voice_live_enabled");
  });

  test("registers every flag's default before fetching, leaving out text the app builds in", () async {
    await source.fetchLiveEnabled();

    final calls = verifyInOrder([() => remoteConfig.setDefaults(captureAny()), () => remoteConfig.fetchAndActivate()]);
    expect(calls.first.captured.single, {
      "voice_live_enabled": false,
      "founder_call_enabled": true,
      "founder_call_after_computer": true,
      "feedback_prompt_interaction_threshold": 5,
      "feedback_prompt_cooldown_days": 14,
      "android_latest_production_submission_build": 0,
      "founder_call_url": "https://cal.com/vespr/sesori-walkthrough",
    });
  });

  test("passes the activated value through", () async {
    expect(await source.fetchLiveEnabled(), isTrue);

    verify(() => remoteConfig.fetchAndActivate()).called(1);
  });

  test("reads the value activated on an earlier launch when the fetch fails", () async {
    when(() => remoteConfig.fetchAndActivate()).thenThrow(StateError("offline"));

    expect(await source.fetchLiveEnabled(), isTrue);
  });
}
