import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/notification_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockAuthenticatedHttpApiClient() extends Mock implements AuthenticatedHttpApiClient;

void main() {
  late MockAuthenticatedHttpApiClient mockClient;
  late NotificationApi api;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue((_) => true);
  });

  setUp(() {
    mockClient = MockAuthenticatedHttpApiClient();
    api = NotificationApi(client: mockClient);
  });

  group("NotificationApi", () {
    test("registerFid posts the FID payload to the register-token route", () async {
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

      await api.registerFid(
        request: const RegisterFidRequest(fid: "fid-1", platform: DevicePlatform.ios, deviceId: null),
      );

      verify(
        () => mockClient.post<bool>(
          Uri.parse("$authBaseUrl/notifications/register-token"),
          fromJson: any(named: "fromJson"),
          body: {"fid": "fid-1", "platform": "ios"},
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).called(1);
    });

    // The server matches this FID to the per-device notification settings, and
    // retires the device's pre-FID token, by deviceId, so it has to reach the wire.
    test("registerFid sends the device id when one is available", () async {
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

      await api.registerFid(
        request: const RegisterFidRequest(
          fid: "fid-1",
          platform: DevicePlatform.ios,
          deviceId: "de250236-dd17-4fbf-a37e-4fcf5dc8c86b",
        ),
      );

      verify(
        () => mockClient.post<bool>(
          Uri.parse("$authBaseUrl/notifications/register-token"),
          fromJson: any(named: "fromJson"),
          body: {
            "fid": "fid-1",
            "platform": "ios",
            "deviceId": "de250236-dd17-4fbf-a37e-4fcf5dc8c86b",
          },
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).called(1);
    });

    // The server accepts an absent deviceId but rejects an explicit null, so a
    // serialized null would fail every registration with a 400.
    test("registerFid omits the device id key entirely when there is none", () async {
      const request = RegisterFidRequest(fid: "fid-1", platform: DevicePlatform.ios, deviceId: null);

      expect(request.toJson().containsKey("deviceId"), isFalse);
    });

    test("unregisterFid deletes the percent-encoded FID path", () async {
      when(
        () => mockClient.delete<bool>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(true));

      await api.unregisterFid(fid: "abc/123+fid");

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
        Uri.parse("$authBaseUrl/notifications/fids/abc%2F123%2Bfid"),
      );
    });

    test("registerFid throws ApiError on non-success response", () async {
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
        api.registerFid(
          request: const RegisterFidRequest(
            fid: "fid-1",
            platform: DevicePlatform.android,
            deviceId: null,
          ),
        ),
        throwsA(isA<NonSuccessCodeError>()),
      );
    });
  });
}
