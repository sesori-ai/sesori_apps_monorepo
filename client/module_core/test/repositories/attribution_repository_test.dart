import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:test/test.dart";

class _MockAttributionApi() extends Mock implements AttributionApi;

void main() {
  late _MockAttributionApi api;

  setUpAll(() {
    registerFallbackValue(AttributionEvent.accountLogin);
  });

  setUp(() {
    api = _MockAttributionApi();
  });

  test("maps SDK acceptance and failure without throwing", () async {
    final repository = AttributionRepository(api: api);
    when(() => api.logEvent(event: any(named: "event"))).thenAnswer((_) async {});

    expect(
      await repository.logEvent(event: AttributionEvent.accountCreated),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    when(() => api.logEvent(event: any(named: "event"))).thenThrow(StateError("sdk unavailable"));
    expect(
      await repository.logEvent(event: AttributionEvent.accountLogin),
      AnalyticsDeliveryResult.failed,
    );
  });

  test("a stalled SDK operation fails after the bounded delivery deadline", () async {
    final repository = AttributionRepository.withDeliveryDeadline(
      api: api,
      deliveryDeadline: Duration.zero,
    );
    when(() => api.logEvent(event: any(named: "event"))).thenAnswer((_) => Completer<void>().future);

    expect(
      await repository.logEvent(event: AttributionEvent.accountLogin),
      AnalyticsDeliveryResult.failed,
    );
  });
}
