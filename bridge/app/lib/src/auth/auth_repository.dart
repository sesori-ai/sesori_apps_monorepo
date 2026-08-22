import "package:sesori_shared/sesori_shared.dart";

import "auth_api.dart";

sealed class const AuthUserLookup();

final class const AuthUserFound({required final AuthMeResponse response}) extends AuthUserLookup;

final class const AuthUserRejected({required final int statusCode}) extends AuthUserLookup;

sealed class const AuthTokenRefresh();

final class const AuthTokenRefreshed({required final AuthResponse response}) extends AuthTokenRefresh;

final class const AuthTokenRefreshRejected({required final int statusCode}) extends AuthTokenRefresh;

class AuthRepository({required final AuthApi _api}) {
  Future<AuthUserLookup> lookupCurrentUser({required String accessToken}) async {
    try {
      return AuthUserFound(response: await _api.getCurrentUser(accessToken: accessToken));
    } on AuthApiException catch (error) {
      return AuthUserRejected(statusCode: error.statusCode);
    }
  }

  Future<String> fetchUsername({required String accessToken}) async {
    final result = await lookupCurrentUser(accessToken: accessToken);
    return switch (result) {
      AuthUserFound(:final response) => response.user.providerUsername ?? "unknown-user",
      AuthUserRejected(:final statusCode) => throw Exception("auth me returned status $statusCode"),
    };
  }

  Future<AuthTokenRefresh> refreshToken({required String refreshToken}) async {
    try {
      return AuthTokenRefreshed(response: await _api.refreshToken(refreshToken: refreshToken));
    } on AuthApiException catch (error) {
      return AuthTokenRefreshRejected(statusCode: error.statusCode);
    }
  }
}
