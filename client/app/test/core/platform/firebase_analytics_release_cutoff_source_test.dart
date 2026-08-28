import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_analytics_release_cutoff_source.dart";

class _MockFirebaseRemoteConfig() extends Mock implements FirebaseRemoteConfig;

void main() {
  late _MockFirebaseRemoteConfig remoteConfig;
  late FirebaseAnalyticsReleaseCutoffSource source;

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
    source = FirebaseAnalyticsReleaseCutoffSource(remoteConfig: remoteConfig);
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.fetch()).thenAnswer((_) async {});
    when(() => remoteConfig.lastFetchStatus).thenReturn(RemoteConfigFetchStatus.success);
    when(() => remoteConfig.activate()).thenAnswer((_) async => true);
    when(
      () => remoteConfig.getInt(FirebaseAnalyticsReleaseCutoffSource.parameterKey),
    ).thenReturn(738);
  });

  test("forces a fresh short-timeout fetch and returns the activated cutoff", () async {
    expect(await source.fetchLatestSubmittedProductionBuild(), 738);

    final settings = verify(() => remoteConfig.setConfigSettings(captureAny())).captured.single as RemoteConfigSettings;
    expect(settings.fetchTimeout, const Duration(seconds: 3));
    expect(settings.minimumFetchInterval, Duration.zero);
    verifyInOrder([
      () => remoteConfig.fetch(),
      () => remoteConfig.lastFetchStatus,
      () => remoteConfig.activate(),
      () => remoteConfig.getInt(FirebaseAnalyticsReleaseCutoffSource.parameterKey),
    ]);
  });

  test("returns unavailable when the fetch status is not successful", () async {
    when(() => remoteConfig.lastFetchStatus).thenReturn(RemoteConfigFetchStatus.failure);

    expect(await source.fetchLatestSubmittedProductionBuild(), isNull);

    verifyNever(() => remoteConfig.activate());
  });

  test("returns unavailable when the fetch fails", () async {
    when(() => remoteConfig.fetch()).thenThrow(StateError("offline"));

    expect(await source.fetchLatestSubmittedProductionBuild(), isNull);

    verifyNever(() => remoteConfig.activate());
  });

  test("returns unavailable when activation fails", () async {
    when(() => remoteConfig.activate()).thenThrow(StateError("activate failed"));

    expect(await source.fetchLatestSubmittedProductionBuild(), isNull);
  });
}
