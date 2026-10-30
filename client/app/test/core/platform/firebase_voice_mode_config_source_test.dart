import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_remote_config_client.dart";
import "package:sesori_mobile/core/platform/firebase_voice_mode_config_source.dart";

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
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.getBool(FirebaseVoiceModeConfigSource.liveEnabledKey)).thenReturn(true);
    when(() => remoteConfig.getString(FirebaseVoiceModeConfigSource.presentationKey)).thenReturn("panel");
  });

  test("uses the agreed parameter keys", () {
    expect(FirebaseVoiceModeConfigSource.liveEnabledKey, "voice_live_enabled");
    expect(FirebaseVoiceModeConfigSource.presentationKey, "voice_live_presentation");
  });

  test("passes the activated values through unparsed", () async {
    expect(await source.fetchValues(), (liveEnabled: true, presentation: "panel"));

    verify(() => remoteConfig.fetchAndActivate()).called(1);
  });

  test("an unset presentation reads as null", () async {
    when(() => remoteConfig.getString(FirebaseVoiceModeConfigSource.presentationKey)).thenReturn("");

    expect(await source.fetchValues(), (liveEnabled: true, presentation: null));
  });

  test("reads the values activated on an earlier launch when the fetch fails", () async {
    when(() => remoteConfig.fetchAndActivate()).thenThrow(StateError("offline"));

    expect(await source.fetchValues(), (liveEnabled: true, presentation: "panel"));
  });
}
