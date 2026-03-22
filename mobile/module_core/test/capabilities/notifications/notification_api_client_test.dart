import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockAuthenticatedHttpApiClient extends Mock implements AuthenticatedHttpApiClient {}

void main() {
  late MockAuthenticatedHttpApiClient mockClient;
  late NotificationApiClient apiClient;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue((_) => true);
  });

  setUp(() {
    mockClient = MockAuthenticatedHttpApiClient();
    apiClient = NotificationApiClient(mockClient);
  });

  group("NotificationApiClient", () {
    test("registerToken posts token payload to auth API", () async {
      when(
        () => mockClient.post<bool>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(true));

      await apiClient.registerToken(token: "device-token", platform: "ios");

      verify(
        () => mockClient.post<bool>(
          Uri.parse("$authBaseUrl/notifications/register-token"),
          fromJson: any(named: "fromJson"),
          body: {"token": "device-token", "platform": "ios"},
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).called(1);
    });

    test("unregisterToken percent-encodes token in path", () async {
      when(
        () => mockClient.delete<bool>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(true));

      await apiClient.unregisterToken("abc/123+token");

      final captured = verify(
        () => mockClient.delete<bool>(
          captureAny(),
          fromJson: captureAny(named: "fromJson"),
          headers: captureAny(named: "headers"),
          contentType: captureAny(named: "contentType"),
          logBody: captureAny(named: "logBody"),
        ),
      ).captured;

      expect(
        captured[0],
        Uri.parse("$authBaseUrl/notifications/tokens/abc%2F123%2Btoken"),
      );
    });

    test("registerToken throws ApiError on non-success response", () async {
      when(
        () => mockClient.post<bool>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "error")));

      await expectLater(
        apiClient.registerToken(token: "device-token", platform: "android"),
        throwsA(isA<NonSuccessCodeError>()),
      );
    });
  });
}
