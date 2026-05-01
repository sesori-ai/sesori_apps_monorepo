import "dart:io";

import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/src/auth_manager.dart";
import "package:sesori_auth/src/client/api_error.dart";
import "package:sesori_auth/src/client/api_response.dart";
import "package:sesori_auth/src/client/authenticated_http_api_client.dart";
import "package:sesori_auth/src/client/http_api_client.dart";
import "package:test/test.dart";

class MockHttpApiClient extends Mock implements HttpApiClient {}

class MockAuthManager extends Mock implements AuthManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(ContentType.json);
    registerFallbackValue(http.MultipartFile.fromString("audio", "fake"));
    registerFallbackValue(_fakeFromJson);
  });

  late MockHttpApiClient mockHttpApiClient;
  late MockAuthManager mockAuth;
  late AuthenticatedHttpApiClient client;

  const accessToken = "access-token-v1";
  const refreshedToken = "access-token-v2";
  final testUrl = Uri.parse("https://api.example.com/resource");

  setUp(() {
    mockHttpApiClient = MockHttpApiClient();
    mockAuth = MockAuthManager();
    client = AuthenticatedHttpApiClient(mockHttpApiClient, mockAuth);
  });

  group("get", () {
    test("returns notAuthenticated when no token is available", () async {
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => null);

      final response = await client.get<String>(testUrl, fromJson: _parseString);

      expect(response, isA<ErrorResponse<String>>());
      final error = (response as ErrorResponse<String>).error;
      expect(error, isA<NotAuthenticatedError>());
      verifyNever(
        () => mockHttpApiClient.get<String>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      );
    });

    test("injects Authorization header", () async {
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(
        () => mockHttpApiClient.get<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("ok"));

      await client.get<String>(testUrl, fromJson: _parseString, headers: {"X-Test": "1"});

      final captured = verify(
        () => mockHttpApiClient.get<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: captureAny(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      );
      final headers = captured.captured.first as Map<String, String>;
      expect(headers["Authorization"], "Bearer $accessToken");
      expect(headers["X-Test"], "1");
    });

    test("retries once with force refresh on 401 response", () async {
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(() => mockAuth.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async => refreshedToken);
      when(
        () => mockHttpApiClient.get<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((invocation) async {
        final headers = invocation.namedArguments[#headers] as Map<String, String>?;
        if (headers?["Authorization"] == "Bearer $accessToken") {
          return ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized"),
          );
        }
        return ApiResponse.success("retried");
      });

      final response = await client.get<String>(testUrl, fromJson: _parseString);

      expect(response, isA<SuccessResponse<String>>());
      expect((response as SuccessResponse<String>).data, "retried");
      verify(() => mockAuth.getFreshAccessToken()).called(1);
      verify(() => mockAuth.getFreshAccessToken(forceRefresh: true)).called(1);
      verify(
        () => mockHttpApiClient.get<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).called(2);
    });
  });

  group("postMultipart", () {
    test("returns original 401 when force refresh fails", () async {
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(() => mockAuth.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async => null);
      when(
        () => mockHttpApiClient.postMultipart<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          files: any(named: "files"),
          headers: any(named: "headers"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized"),
        ),
      );

      final response = await client.postMultipart<String>(
        testUrl,
        fromJson: _parseString,
        createFiles: () async => [http.MultipartFile.fromString("audio", "bytes")],
      );

      expect(response, isA<ErrorResponse<String>>());
      verify(() => mockAuth.getFreshAccessToken(forceRefresh: true)).called(1);
      verify(
        () => mockHttpApiClient.postMultipart<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          files: any(named: "files"),
          headers: any(named: "headers"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).called(1);
    });

    test("retries multipart and recreates files after 401", () async {
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(() => mockAuth.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async => refreshedToken);

      var callCount = 0;
      when(
        () => mockHttpApiClient.postMultipart<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          files: any(named: "files"),
          headers: any(named: "headers"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized"),
          );
        }
        return ApiResponse.success("ok");
      });

      var createFilesCalls = 0;
      final response = await client.postMultipart<String>(
        testUrl,
        fromJson: _parseString,
        createFiles: () async {
          createFilesCalls++;
          return [http.MultipartFile.fromString("audio", "bytes")];
        },
      );

      expect(response, isA<SuccessResponse<String>>());
      expect(createFilesCalls, 2);
      verify(
        () => mockHttpApiClient.postMultipart<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          files: any(named: "files"),
          headers: captureAny(named: "headers"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).called(2);
    });
  });
}

// ignore: no_slop_linter/prefer_specific_type, mocktail fallback
String _fakeFromJson(dynamic json) => "";

// ignore: no_slop_linter/prefer_specific_type, test parser callback
String _parseString(dynamic json) => json as String;
