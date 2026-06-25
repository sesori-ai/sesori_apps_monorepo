import "dart:developer" as developer;

import "package:injectable/injectable.dart";

import "package:sesori_shared/sesori_shared.dart";

import "../platform/secure_storage.dart";

@lazySingleton
class OAuthStorageService {
  static const _pkceVerifierKey = "pkce_verifier";
  static const _oauthProviderKey = "oauth_provider";
  static const _oauthSessionTokenKey = "oauth_session_token";
  static const _oauthSessionExpiryKey = "oauth_session_expiry";
  final SecureStorage _storage;

  OAuthStorageService(SecureStorage storage) : _storage = storage;

  Future<void> saveAuthProviderAndPkceVerifier({required String codeVerifier, required AuthProvider provider}) async {
    try {
      await _storage.write(key: _pkceVerifierKey, value: codeVerifier);
      await _storage.write(key: _oauthProviderKey, value: provider.key);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to persist OAuth provider or PKCE verifier",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }

  Future<String?> getPkceVerifier() async {
    try {
      return await _storage.read(key: _pkceVerifierKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to read PKCE verifier",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }

  Future<void> clearPkceVerifier() async {
    try {
      await _storage.delete(key: _pkceVerifierKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to clear PKCE verifier",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }

  Future<AuthProvider?> getAuthProvider() async {
    try {
      final providerKey = await _storage.read(key: _oauthProviderKey);
      return AuthProvider.fromKey(providerKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to read OAuth provider",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }

  Future<void> clearAuthProvider() async {
    try {
      await _storage.delete(key: _oauthProviderKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to clear OAuth provider",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }

  Future<void> saveOAuthSession({required String sessionToken, required DateTime expiresAt}) async {
    try {
      await _storage.write(key: _oauthSessionTokenKey, value: sessionToken);
      await _storage.write(key: _oauthSessionExpiryKey, value: expiresAt.toIso8601String());
    } catch (error, stackTrace) {
      developer.log(
        "Failed to persist OAuth session",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }

  Future<({String? sessionToken, DateTime? expiresAt})> getOAuthSession() async {
    try {
      final sessionToken = await _storage.read(key: _oauthSessionTokenKey);
      final expiryString = await _storage.read(key: _oauthSessionExpiryKey);
      if (sessionToken == null || expiryString == null) {
        return (sessionToken: null, expiresAt: null);
      }
      final expiresAt = DateTime.tryParse(expiryString);
      if (expiresAt == null) {
        await _storage.delete(key: _oauthSessionTokenKey);
        await _storage.delete(key: _oauthSessionExpiryKey);
        return (sessionToken: null, expiresAt: null);
      }
      return (sessionToken: sessionToken, expiresAt: expiresAt);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to read OAuth session",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return (sessionToken: null, expiresAt: null);
    }
  }

  Future<void> clearOAuthSession() async {
    try {
      await _storage.delete(key: _oauthSessionTokenKey);
      await _storage.delete(key: _oauthSessionExpiryKey);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to clear OAuth session",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      rethrow;
    }
  }
}
