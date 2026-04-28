import "dart:developer" as developer;

import "package:injectable/injectable.dart";

import "../auth_config.dart";
import "../platform/secure_storage.dart";

@lazySingleton
class OAuthStorageService {
  static const _pkceVerifierKey = "pkce_verifier";
  static const _oauthProviderKey = "oauth_provider";
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
}
