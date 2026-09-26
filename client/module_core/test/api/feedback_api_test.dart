import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockAuthenticatedHttpApiClient() extends Mock implements AuthenticatedHttpApiClient;

void main() {
  late _MockAuthenticatedHttpApiClient client;
  late FeedbackApi api;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue((_) => true);
  });

  setUp(() {
    client = _MockAuthenticatedHttpApiClient();
    api = FeedbackApi(client: client);
  });

  void answer(ApiResponse<bool> response) => when(
    () => client.post<bool>(
      any(),
      fromJson: any(named: "fromJson"),
      headers: any(named: "headers"),
      body: any(named: "body"),
      contentType: any(named: "contentType"),
      logBody: any(named: "logBody"),
    ),
  ).thenAnswer((_) async => response);

  Map<String, dynamic> sentBody() =>
      verify(
            () => client.post<bool>(
              Uri.parse("$authBaseUrl/feedback"),
              fromJson: any(named: "fromJson"),
              headers: any(named: "headers"),
              body: captureAny(named: "body"),
              contentType: any(named: "contentType"),
              logBody: false,
            ),
          ).captured.single
          as Map<String, dynamic>;

  test("posts the server's wire values and omits a missing message", () async {
    answer(ApiResponse.success(true));

    await api.submit(
      request: const FeedbackSubmitRequest(
        issues: FeedbackIssue.values,
        message: null,
        source: FeedbackSource.automatic,
        platform: DevicePlatform.android,
        appVersion: "1.6.0",
      ),
    );

    expect(sentBody(), {
      "issues": ["hard_to_navigate", "connection_drops", "notifications_missing", "app_slow"],
      "source": "automatic",
      "platform": "android",
      "appVersion": "1.6.0",
    });
  });

  test("sends the message when there is one", () async {
    answer(ApiResponse.success(true));

    await api.submit(
      request: const FeedbackSubmitRequest(
        issues: [],
        message: "Fixture feedback",
        source: FeedbackSource.settings,
        platform: DevicePlatform.ios,
        appVersion: "1.6.0",
      ),
    );

    expect(sentBody(), {
      "issues": <String>[],
      "message": "Fixture feedback",
      "source": "settings",
      "platform": "ios",
      "appVersion": "1.6.0",
    });
  });

  test("throws the API error on a failed response", () async {
    answer(ApiResponse.error(ApiError.nonSuccessCode(errorCode: 429, rawErrorString: "rate limited")));

    await expectLater(
      api.submit(
        request: const FeedbackSubmitRequest(
          issues: [],
          message: null,
          source: FeedbackSource.settings,
          platform: DevicePlatform.ios,
          appVersion: "1.6.0",
        ),
      ),
      throwsA(isA<NonSuccessCodeError>()),
    );
  });
}
