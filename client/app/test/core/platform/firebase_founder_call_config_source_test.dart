import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_founder_call_config_source.dart";
import "package:sesori_mobile/core/platform/firebase_remote_config_client.dart";

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
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.getValue(any())).thenReturn(RemoteConfigValue(null, ValueSource.valueStatic));
  });

  void setRemote(String key, String value) {
    when(() => remoteConfig.getValue(key)).thenReturn(RemoteConfigValue(value.codeUnits, ValueSource.valueRemote));
  }

  test("reads unset keys as null so the built-in defaults apply", () async {
    expect(await source.fetchValues(), (
      enabled: null,
      afterComputer: null,
      bookingUrl: null,
      title: null,
      message: null,
      buttonLabel: null,
    ));
  });

  test("reads the console values and treats an empty value as unset", () async {
    setRemote(FirebaseFounderCallConfigSource.enabledKey, "false");
    setRemote(FirebaseFounderCallConfigSource.afterComputerKey, "");
    setRemote(FirebaseFounderCallConfigSource.bookingUrlKey, "https://cal.com/example");
    setRemote(FirebaseFounderCallConfigSource.titleKey, "Talk to the founder");
    setRemote(FirebaseFounderCallConfigSource.messageKey, "");
    setRemote(FirebaseFounderCallConfigSource.buttonLabelKey, "Pick a time");

    expect(await source.fetchValues(), (
      enabled: false,
      afterComputer: null,
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
