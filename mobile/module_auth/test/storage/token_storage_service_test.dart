import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_auth/src/storage/oauth_storage_service.dart";
import "package:sesori_auth/src/storage/token_storage_service.dart";
import "package:sesori_shared/sesori_shared.dart" show parseJwtExpiry;
import "package:test/test.dart";

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage mockStorage;
  late TokenStorageService tokenStorageService;
  late OAuthStorageService oauthStorageService;

  setUp(() {
    mockStorage = MockSecureStorage();
    tokenStorageService = TokenStorageService(mockStorage);
    oauthStorageService = OAuthStorageService(mockStorage);
  });

  group("TokenStorageService", () {
    test("saveTokens writes access and refresh tokens", () async {
      // given
      when(() => mockStorage.write(key: "access_token", value: "test_access_token_12345")).thenAnswer((_) async {
        return;
      });
      when(() => mockStorage.write(key: "refresh_token", value: "test_refresh_token_67890")).thenAnswer((_) async {
        return;
      });

      // when
      await tokenStorageService.saveTokens(
        accessToken: "test_access_token_12345",
        refreshToken: "test_refresh_token_67890",
      );

      // then
      verify(() => mockStorage.write(key: "access_token", value: "test_access_token_12345")).called(1);
      verify(() => mockStorage.write(key: "refresh_token", value: "test_refresh_token_67890")).called(1);
    });

    test("saveTokens rethrows on storage error", () async {
      // given
      final error = Exception("write failed");
      when(() => mockStorage.write(key: "access_token", value: "token")).thenThrow(error);

      // when/then
      await expectLater(
        tokenStorageService.saveTokens(accessToken: "token", refreshToken: "refresh"),
        throwsA(same(error)),
      );
      verify(() => mockStorage.write(key: "access_token", value: "token")).called(1);
    });

    test("getAccessToken returns null when storage returns null", () async {
      // given
      when(() => mockStorage.read(key: "access_token")).thenAnswer((_) async => null);

      // when
      final result = await tokenStorageService.getAccessToken();

      // then
      verify(() => mockStorage.read(key: "access_token")).called(1);
      expect(result, isNull);
    });

    test("getAccessToken returns null when storage returns empty string", () async {
      // given
      when(() => mockStorage.read(key: "access_token")).thenAnswer((_) async => "");

      // when
      final result = await tokenStorageService.getAccessToken();

      // then
      verify(() => mockStorage.read(key: "access_token")).called(1);
      expect(result, isNull);
    });

    test("getAccessToken returns null when token is not a parseable JWT", () async {
      // given
      when(() => mockStorage.read(key: "access_token")).thenAnswer((_) async => "opaque-token");

      // when
      final result = await tokenStorageService.getAccessToken();

      // then
      verify(() => mockStorage.read(key: "access_token")).called(1);
      expect(result, isNull);
    });

    test("getAccessToken returns null when JWT is expired", () async {
      // given
      final pastExp = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      when(
        () => mockStorage.read(key: "access_token"),
      ).thenAnswer((_) async => buildJwt(exp: pastExp.millisecondsSinceEpoch ~/ 1000));

      // when
      final result = await tokenStorageService.getAccessToken();

      // then
      verify(() => mockStorage.read(key: "access_token")).called(1);
      expect(result, isNull);
    });

    test("getAccessToken returns token and validityLeft for valid non-expired JWT", () async {
      // given
      final futureExp = DateTime.now().toUtc().add(const Duration(minutes: 10));
      final accessToken = buildJwt(exp: futureExp.millisecondsSinceEpoch ~/ 1000);
      when(() => mockStorage.read(key: "access_token")).thenAnswer((_) async => accessToken);

      // when
      final result = await tokenStorageService.getAccessToken();

      // then
      verify(() => mockStorage.read(key: "access_token")).called(1);
      expect(result, isNotNull);
      expect(result?.token, accessToken);
      expect(result!.validityLeft, greaterThan(Duration.zero));
      expect(result.validityLeft, lessThanOrEqualTo(const Duration(minutes: 10)));
    });

    test("getRefreshToken reads with correct key and returns value", () async {
      // given
      when(() => mockStorage.read(key: "refresh_token")).thenAnswer((_) async => "stored_refresh_token");

      // when
      final result = await tokenStorageService.getRefreshToken();

      // then
      verify(() => mockStorage.read(key: "refresh_token")).called(1);
      expect(result, "stored_refresh_token");
    });

    test("getRefreshToken returns null on storage error", () async {
      // given
      when(() => mockStorage.read(key: "refresh_token")).thenThrow(Exception("read failed"));

      // when
      final result = await tokenStorageService.getRefreshToken();

      // then
      verify(() => mockStorage.read(key: "refresh_token")).called(1);
      expect(result, isNull);
    });

    test("clearTokens deletes both access and refresh token keys", () async {
      // given
      when(() => mockStorage.delete(key: "access_token")).thenAnswer((_) async {
        return;
      });
      when(() => mockStorage.delete(key: "refresh_token")).thenAnswer((_) async {
        return;
      });

      // when
      await tokenStorageService.clearTokens();

      // then
      verify(() => mockStorage.delete(key: "access_token")).called(1);
      verify(() => mockStorage.delete(key: "refresh_token")).called(1);
    });

    group("parseJwtExpiry", () {
      test("valid JWT with exp returns correct DateTime", () {
        final exp = DateTime.utc(2040, 1, 1, 12, 30, 45);
        final token = buildJwt(exp: exp.millisecondsSinceEpoch ~/ 1000);

        final result = parseJwtExpiry(token);

        expect(result, exp);
      });

      test("JWT with no exp returns null", () {
        final payload = base64Url.encode(utf8.encode('{"sub":"user-1"}'));
        final token = "eyJhbGciOiJIUzI1NiJ9.$payload.fake_sig";

        final result = parseJwtExpiry(token);

        expect(result, isNull);
      });

      test("JWT with non-int exp returns null", () {
        final payload = base64Url.encode(utf8.encode('{"exp":"1700000000"}'));
        final token = "eyJhbGciOiJIUzI1NiJ9.$payload.fake_sig";

        final result = parseJwtExpiry(token);

        expect(result, isNull);
      });

      test("token with fewer than 3 parts returns null", () {
        final result = parseJwtExpiry("not.a.jwt");

        expect(result, isNull);
      });

      test("invalid base64 payload returns null", () {
        const token = "eyJhbGciOiJIUzI1NiJ9.invalid%%%payload.fake_sig";

        final result = parseJwtExpiry(token);

        expect(result, isNull);
      });

      test("invalid JSON payload returns null", () {
        final payload = base64Url.encode(utf8.encode("this is not json"));
        final token = "eyJhbGciOiJIUzI1NiJ9.$payload.fake_sig";

        final result = parseJwtExpiry(token);

        expect(result, isNull);
      });
    });
  });

  group("OAuthStorageService", () {
    test("saveAuthProviderAndPkceVerifier writes provider and verifier", () async {
      // given
      when(() => mockStorage.write(key: "pkce_verifier", value: "test_pkce_verifier")).thenAnswer((_) async {
        return;
      });
      when(() => mockStorage.write(key: "oauth_provider", value: "github")).thenAnswer((_) async {
        return;
      });

      // when
      await oauthStorageService.saveAuthProviderAndPkceVerifier(
        codeVerifier: "test_pkce_verifier",
        provider: AuthProvider.github,
      );

      // then
      verify(() => mockStorage.write(key: "pkce_verifier", value: "test_pkce_verifier")).called(1);
      verify(() => mockStorage.write(key: "oauth_provider", value: "github")).called(1);
    });

    test("getPkceVerifier reads with correct key and returns value", () async {
      // given
      when(() => mockStorage.read(key: "pkce_verifier")).thenAnswer((_) async => "stored_pkce_verifier");

      // when
      final result = await oauthStorageService.getPkceVerifier();

      // then
      verify(() => mockStorage.read(key: "pkce_verifier")).called(1);
      expect(result, "stored_pkce_verifier");
    });

    test("clearPkceVerifier deletes with correct key", () async {
      // given
      when(() => mockStorage.delete(key: "pkce_verifier")).thenAnswer((_) async {
        return;
      });

      // when
      await oauthStorageService.clearPkceVerifier();

      // then
      verify(() => mockStorage.delete(key: "pkce_verifier")).called(1);
    });

    test("getAuthProvider returns enum for stored provider key", () async {
      // given
      when(() => mockStorage.read(key: "oauth_provider")).thenAnswer((_) async => "google");

      // when
      final result = await oauthStorageService.getAuthProvider();

      // then
      verify(() => mockStorage.read(key: "oauth_provider")).called(1);
      expect(result, AuthProvider.google);
    });

    test("getAuthProvider returns null for unknown provider key", () async {
      // given
      when(() => mockStorage.read(key: "oauth_provider")).thenAnswer((_) async => "unknown");

      // when
      final result = await oauthStorageService.getAuthProvider();

      // then
      verify(() => mockStorage.read(key: "oauth_provider")).called(1);
      expect(result, isNull);
    });

    test("clearAuthProvider deletes with correct key", () async {
      // given
      when(() => mockStorage.delete(key: "oauth_provider")).thenAnswer((_) async {
        return;
      });

      // when
      await oauthStorageService.clearAuthProvider();

      // then
      verify(() => mockStorage.delete(key: "oauth_provider")).called(1);
    });
  });
}

String buildJwt({required int exp}) {
  final payload = base64Url.encode(utf8.encode('{"exp":$exp}'));
  return "eyJhbGciOiJIUzI1NiJ9.$payload.fake_sig";
}
