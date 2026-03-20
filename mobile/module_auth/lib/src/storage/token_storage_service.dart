import "dart:convert";
import "dart:developer" as developer;

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../platform/secure_storage.dart";

@lazySingleton
class TokenStorageService {
  static const _accessTokenKey = "access_token";
  static const _refreshTokenKey = "refresh_token";

  final SecureStorage _storage;

  TokenStorageService(SecureStorage storage) : _storage = storage;

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to persist auth tokens",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }

  Future<String?> _getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to read access token",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }

  Future<({String token, Duration validityLeft})?> getAccessToken() async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) return null;

    final expiry = parseJwtExpiry(token);
    if (expiry == null) return null;

    final validityLeft = expiry.difference(DateTime.now().toUtc());
    if (validityLeft.isNegative) return null; // Token is expired

    return (token: token, validityLeft: validityLeft);
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to read refresh token",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }

  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to clear auth tokens",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }

  /// Parses the `exp` claim from a JWT [token] and returns the expiry as a
  /// UTC [DateTime]. Returns `null` if the token is malformed or has no `exp`.
  @visibleForTesting
  static DateTime? parseJwtExpiry(String token) {
    try {
      final parts = token.split(".");
      if (parts.length != 3) return null;

      // Base64url payload — add padding to make length a multiple of 4.
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload = "$payload==";
        case 3:
          payload = "$payload=";
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json["exp"];
      if (exp is! int) return null;

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to parse JWT expiry",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }
}
