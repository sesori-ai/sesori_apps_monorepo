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
  });

  test("uses the agreed parameter key", () {
    expect(FirebaseVoiceModeConfigSource.liveEnabledKey, "voice_live_enabled");
  });

  test("uses the agreed on-device key", () {
    expect(FirebaseVoiceModeConfigSource.onDeviceEnabledKey, "voice_on_device_enabled");
  });

  test("leaves on-device on while the key is unset, and off only when set to false", () async {
    void setValue(RemoteConfigValue value) {
      when(() => remoteConfig.getValue(FirebaseVoiceModeConfigSource.onDeviceEnabledKey)).thenReturn(value);
    }

    setValue(RemoteConfigValue(null, ValueSource.valueStatic));
    expect(await source.fetchOnDeviceEnabled(), isTrue);

    setValue(RemoteConfigValue("true".codeUnits, ValueSource.valueRemote));
    expect(await source.fetchOnDeviceEnabled(), isTrue);

    setValue(RemoteConfigValue("false".codeUnits, ValueSource.valueRemote));
    expect(await source.fetchOnDeviceEnabled(), isFalse);
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
