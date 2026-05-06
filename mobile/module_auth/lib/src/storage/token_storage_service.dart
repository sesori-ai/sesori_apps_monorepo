import "dart:developer" as developer;

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart" show parseJwtExpiry;

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

    final validityLeft = _validityLeft(token);
    if (validityLeft == null || validityLeft.isNegative) return null;

    return (token: token, validityLeft: validityLeft);
  }

  Future<bool> hasLocallyValidSession() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    if (await getAccessToken() != null) return true;

    final validityLeft = _validityLeft(refreshToken);
    return validityLeft != null && !validityLeft.isNegative;
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

  Duration? _validityLeft(String token) {
    final expiry = parseJwtExpiry(token);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now().toUtc());
  }
}
