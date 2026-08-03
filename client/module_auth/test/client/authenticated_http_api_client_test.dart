import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/src/auth_manager.dart";
import "package:sesori_auth/src/client/api_error.dart";
import "package:sesori_auth/src/client/api_response.dart";
import "package:sesori_auth/src/client/authenticated_http_api_client.dart";
import "package:sesori_auth/src/client/http_api_client.dart";
import "package:sesori_auth/src/models/auth_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockHttpApiClient extends Mock implements HttpApiClient {}

class MockAuthManager extends Mock implements AuthManager {}

const _userA = AuthUser(
  id: "user-a",
  provider: AuthProvider.github,
  providerUserId: "github-a",
  providerUsername: "alpha",
);
const _userB = AuthUser(
  id: "user-b",
  provider: AuthProvider.google,
  providerUserId: "google-b",
  providerUsername: "beta",
);

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

  group("put", () {
    test("injects bearer auth and delegates the PUT arguments", () async {
      const body = {"enabled": true};
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(
        () => mockHttpApiClient.put<String>(
          url: testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("ok"));

      final response = await client.put<String>(
        url: testUrl,
        fromJson: _parseString,
        headers: {
          "Authorization": "Bearer stale-token",
          "X-Test": "1",
        },
        body: body,
        contentType: ContentType.text,
        logBody: true,
      );

      expect((response as SuccessResponse<String>).data, "ok");
      final captured = verify(
        () => mockHttpApiClient.put<String>(
          url: testUrl,
          fromJson: _parseString,
          headers: captureAny(named: "headers"),
          body: body,
          contentType: ContentType.text,
          logBody: true,
        ),
      );
      expect(captured.captured.single, {
        "Authorization": "Bearer $accessToken",
        "X-Test": "1",
      });
    });

    test("refreshes and retries only once after 401", () async {
      const body = {"enabled": true};
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(() => mockAuth.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async => refreshedToken);
      when(
        () => mockHttpApiClient.put<String>(
          url: testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized"),
        ),
      );

      final response = await client.put<String>(
        url: testUrl,
        fromJson: _parseString,
        headers: null,
        body: body,
        contentType: null,
        logBody: false,
      );

      expect(
        (response as ErrorResponse<String>).error,
        isA<NonSuccessCodeError>(),
      );
      verify(() => mockAuth.getFreshAccessToken()).called(1);
      verify(() => mockAuth.getFreshAccessToken(forceRefresh: true)).called(1);
      final captured = verify(
        () => mockHttpApiClient.put<String>(
          url: testUrl,
          fromJson: _parseString,
          headers: captureAny(named: "headers"),
          body: body,
          contentType: null,
          logBody: false,
        ),
      );
      expect(captured.callCount, 2);
      expect(captured.captured, [
        {"Authorization": "Bearer $accessToken"},
        {"Authorization": "Bearer $refreshedToken"},
      ]);
    });
  });

  group("account-bound requests", () {
    test("patchForUser injects auth and delegates only for the current account", () async {
      const body = """{"notifications":{"aiInteraction":false}}""";
      when(() => mockAuth.currentState).thenReturn(const AuthState.authenticated(user: _userA));
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(
        () => mockHttpApiClient.patch<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("ok"));

      final response = await client.patchForUser<String>(
        url: testUrl,
        userId: _userA.id,
        fromJson: _parseString,
        body: body,
      );

      expect((response as SuccessResponse<String>).data, "ok");
      final captured = verify(
        () => mockHttpApiClient.patch<String>(
          testUrl,
          fromJson: _parseString,
          headers: captureAny(named: "headers"),
          body: body,
          contentType: null,
          logBody: false,
        ),
      );
      expect(captured.captured.single, {"Authorization": "Bearer $accessToken"});
    });

    test("refuses a request when its initiating account is no longer current", () async {
      when(() => mockAuth.currentState).thenReturn(const AuthState.authenticated(user: _userB));

      final response = await client.getForUser<String>(
        url: testUrl,
        userId: _userA.id,
        fromJson: _parseString,
      );

      expect((response as ErrorResponse<String>).error, isA<NotAuthenticatedError>());
      verifyNever(() => mockAuth.getFreshAccessToken());
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

    test("does not retry a 401 with a token refreshed after an account switch", () async {
      AuthState currentState = const AuthState.authenticated(user: _userA);
      when(() => mockAuth.currentState).thenAnswer((_) => currentState);
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(() => mockAuth.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async {
        currentState = const AuthState.authenticated(user: _userB);
        return refreshedToken;
      });
      when(
        () => mockHttpApiClient.put<String>(
          url: testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized"),
        ),
      );

      final response = await client.putForUser<String>(
        url: testUrl,
        userId: _userA.id,
        fromJson: _parseString,
        body: '{"enabled":false}',
      );

      expect((response as ErrorResponse<String>).error, isA<NotAuthenticatedError>());
      verify(() => mockAuth.getFreshAccessToken(forceRefresh: true)).called(1);
      verify(
        () => mockHttpApiClient.put<String>(
          url: testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          body: any(named: "body"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).called(1);
    });

    test("rejects a failed refresh completed after an account switch", () async {
      var currentState = const AuthState.authenticated(user: _userA);
      when(() => mockAuth.currentState).thenAnswer((_) => currentState);
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(() => mockAuth.getFreshAccessToken(forceRefresh: true)).thenAnswer((_) async {
        currentState = const AuthState.authenticated(user: _userB);
        return null;
      });
      when(
        () => mockHttpApiClient.get<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized"),
        ),
      );

      final response = await client.getForUser<String>(
        url: testUrl,
        userId: _userA.id,
        fromJson: _parseString,
      );

      expect((response as ErrorResponse<String>).error, isA<NotAuthenticatedError>());
    });

    test("rejects a successful response completed after an account switch", () async {
      var currentState = const AuthState.authenticated(user: _userA);
      final responseCompleter = Completer<ApiResponse<String>>();
      when(() => mockAuth.currentState).thenAnswer((_) => currentState);
      when(() => mockAuth.getFreshAccessToken()).thenAnswer((_) async => accessToken);
      when(
        () => mockHttpApiClient.get<String>(
          testUrl,
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) => responseCompleter.future);

      final responseFuture = client.getForUser<String>(
        url: testUrl,
        userId: _userA.id,
        fromJson: _parseString,
      );
      await Future<void>.delayed(Duration.zero);
      currentState = const AuthState.authenticated(user: _userB);
      responseCompleter.complete(ApiResponse.success("stale"));

      final response = await responseFuture;
      expect((response as ErrorResponse<String>).error, isA<NotAuthenticatedError>());
    });

    test("rejects a retry response completed after an account switch", () async {
      var currentState = const AuthState.authenticated(user: _userA);
      final retryCompleter = Completer<ApiResponse<String>>();
      when(() => mockAuth.currentState).thenAnswer((_) => currentState);
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
      ).thenAnswer((invocation) {
        final headers = invocation.namedArguments[#headers] as Map<String, String>?;
        if (headers?["Authorization"] == "Bearer $accessToken") {
          return Future.value(
            ApiResponse.error(ApiError.nonSuccessCode(errorCode: 401, rawErrorString: "unauthorized")),
          );
        }
        return retryCompleter.future;
      });

      final responseFuture = client.getForUser<String>(
        url: testUrl,
        userId: _userA.id,
        fromJson: _parseString,
      );
      await Future<void>.delayed(Duration.zero);
      currentState = const AuthState.authenticated(user: _userB);
      retryCompleter.complete(ApiResponse.success("stale retry"));

      final response = await responseFuture;
      expect((response as ErrorResponse<String>).error, isA<NotAuthenticatedError>());
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
