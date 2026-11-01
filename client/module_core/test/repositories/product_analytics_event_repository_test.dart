import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _FakeEventApi({required final ProductAnalyticsEventDeliveryResult result})
    extends Mock
    implements ProductAnalyticsEventApi {
  final List<({String userId, ProductAnalyticsEventRequest request})> sent = [];

  @override
  Future<ProductAnalyticsEventDeliveryResult> send({
    required String userId,
    required ProductAnalyticsEventRequest request,
  }) async {
    sent.add((userId: userId, request: request));
    return result;
  }
}

void main() {
  test("maps the envelope onto the request, and returns the API's result as it is", () async {
    const failure = ProductAnalyticsEventDeliveryResult.permanentFailure(description: "HTTP 400", cause: null);
    final api = _FakeEventApi(result: failure);

    final result = await ProductAnalyticsEventRepository(api: api).send(
      userId: "user-a",
      platform: ProductAnalyticsEventPlatform.linux,
      appVersion: "1.11.0",
      envelope: ProductAnalyticsEnvelope(
        event: const ProductAnalyticsEvent.sessionQuestionAnswered(),
        occurredAtUtc: DateTime.fromMicrosecondsSinceEpoch(1793232000000000, isUtc: true),
      ),
      params: const {"key": "value"},
    );

    expect(result, failure);
    final attempt = api.sent.single;
    expect(attempt.userId, "user-a");
    expect(attempt.request.toJson(), {
      "schemaVersion": 1,
      "platform": "LINUX",
      "appVersion": "1.11.0",
      "name": "session_question_answered",
      "occurredAtMicros": 1793232000000000,
      "params": {"key": "value"},
    });
  });
}
