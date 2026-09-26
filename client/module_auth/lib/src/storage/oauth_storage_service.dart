import "dart:developer" as developer;

import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../models/auth_secret_key.dart";

@lazySingleton
class OAuthStorageService({required final SecureStorageRepository _storage}) {
  Future<void> saveAuthProviderAndPkceVerifier({required String codeVerifier, required AuthProvider provider}) async {
    try {
      await _storage.write(key: AuthSecretKey.pkceVerifier, value: codeVerifier);
      await _storage.write(key: AuthSecretKey.oauthProvider, value: provider.key);
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
      return await _storage.read(key: AuthSecretKey.pkceVerifier);
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
      await _storage.delete(key: AuthSecretKey.pkceVerifier);
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
      final providerKey = await _storage.read(key: AuthSecretKey.oauthProvider);
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
      await _storage.delete(key: AuthSecretKey.oauthProvider);
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
      await _storage.write(key: AuthSecretKey.oauthSessionToken, value: sessionToken);
      await _storage.write(key: AuthSecretKey.oauthSessionExpiry, value: expiresAt.toIso8601String());
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
      final sessionToken = await _storage.read(key: AuthSecretKey.oauthSessionToken);
      final expiryString = await _storage.read(key: AuthSecretKey.oauthSessionExpiry);
      if (sessionToken == null || expiryString == null) {
        return (sessionToken: null, expiresAt: null);
      }
      final expiresAt = DateTime.tryParse(expiryString);
      if (expiresAt == null) {
        await _storage.delete(key: AuthSecretKey.oauthSessionToken);
        await _storage.delete(key: AuthSecretKey.oauthSessionExpiry);
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
      await _storage.delete(key: AuthSecretKey.oauthSessionToken);
      await _storage.delete(key: AuthSecretKey.oauthSessionExpiry);
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
