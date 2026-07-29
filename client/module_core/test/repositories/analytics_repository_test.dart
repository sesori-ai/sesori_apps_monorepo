import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

const _userKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

class _MockAnalyticsApi extends Mock implements AnalyticsApi {}

void main() {
  late _MockAnalyticsApi api;

  setUpAll(() {
    registerFallbackValue(
      ProductAnalyticsEnvelope(
        event: const ProductAnalyticsEvent.analyticsSchemaReady(),
        occurredAtUtc: DateTime.utc(2026),
      ),
    );
    registerFallbackValue(
      const InstallationAnalyticsEvent.loginAttemptStarted(provider: AnalyticsLoginProvider.github),
    );
  });

  setUp(() {
    api = _MockAnalyticsApi();
  });

  test("product repository maps SDK acceptance and failure without throwing", () async {
    final repository = ProductAnalyticsRepository(api: api);
    final envelope = ProductAnalyticsEnvelope(
      event: const ProductAnalyticsEvent.analyticsSchemaReady(),
      occurredAtUtc: DateTime.utc(2026),
    );
    when(
      () => api.logProductEvent(
        envelope: any(named: "envelope"),
        userKey: _userKey,
      ),
    ).thenAnswer((_) async {});

    expect(
      await repository.logEvent(envelope: envelope, userKey: _userKey),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    when(
      () => api.logProductEvent(
        envelope: any(named: "envelope"),
        userKey: _userKey,
      ),
    ).thenThrow(StateError("sdk unavailable"));
    expect(
      await repository.logEvent(envelope: envelope, userKey: _userKey),
      AnalyticsDeliveryResult.failed,
    );
  });

  test("installation repository maps SDK acceptance and failure without adding account state", () async {
    final repository = InstallationAnalyticsRepository(api: api);
    const event = InstallationAnalyticsEvent.loginAttemptCompleted(provider: AnalyticsLoginProvider.apple);
    when(
      () => api.logInstallationEvent(event: any(named: "event")),
    ).thenAnswer((_) async {});

    expect(
      await repository.logEvent(event: event),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    when(
      () => api.logInstallationEvent(event: any(named: "event")),
    ).thenThrow(StateError("sdk unavailable"));
    expect(
      await repository.logEvent(event: event),
      AnalyticsDeliveryResult.failed,
    );
  });
}
