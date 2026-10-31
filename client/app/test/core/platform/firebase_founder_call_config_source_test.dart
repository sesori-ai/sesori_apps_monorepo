import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_founder_call_config_source.dart";
import "package:sesori_mobile/core/platform/firebase_remote_config_client.dart";
import "package:sesori_mobile/core/platform/remote_config_flags.dart";

class _MockFirebaseRemoteConfig() extends Mock implements FirebaseRemoteConfig;

void main() {
  late _MockFirebaseRemoteConfig remoteConfig;
  late FirebaseFounderCallConfigSource source;

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
    source = FirebaseFounderCallConfigSource(
      remoteConfigClient: FirebaseRemoteConfigClient(remoteConfig: remoteConfig),
    );
    when(() => remoteConfig.setDefaults(any())).thenAnswer((_) async {});
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.getValue(any())).thenReturn(RemoteConfigValue("".codeUnits, ValueSource.valueRemote));
    when(() => remoteConfig.getString(any())).thenReturn("");
  });

  test("reads the console values, and blank ones as the default or no text", () async {
    when(
      () => remoteConfig.getValue(BoolRemoteConfig.founderCallEnabled.key),
    ).thenReturn(RemoteConfigValue("false".codeUnits, ValueSource.valueRemote));
    when(() => remoteConfig.getString(StringRemoteConfig.founderCallUrl.key)).thenReturn("https://cal.com/example");
    when(() => remoteConfig.getString(StringRemoteConfig.founderCallTitle.key)).thenReturn("Talk to the founder");
    when(() => remoteConfig.getString(StringRemoteConfig.founderCallButton.key)).thenReturn("Pick a time");

    expect(await source.fetchValues(), (
      enabled: false,
      afterComputer: true,
      bookingUrl: "https://cal.com/example",
      title: "Talk to the founder",
      message: null,
      buttonLabel: "Pick a time",
    ));
  });

  test("fetches once per launch", () async {
    await source.fetchValues();
    await source.fetchValues();

    verify(() => remoteConfig.fetchAndActivate()).called(1);
  });
}
