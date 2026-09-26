import "dart:developer" as developer;

import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../models/auth_secret_key.dart";

/// The provider key of the last interactive sign-in on this device, and
/// nothing else. Logout leaves it in place, so the login screen can mark the
/// method the user signed in with last time.
@lazySingleton
class LastSignInStorage({required final SecureStorageRepository _storage}) {
  /// Best effort: a failed write is logged and never fails the sign-in.
  Future<void> save({required AuthProvider provider}) async {
    try {
      await _storage.write(key: AuthSecretKey.lastSignInProvider, value: provider.key);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to persist the last sign-in provider",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
    }
  }

  Future<AuthProvider?> read() async {
    try {
      return AuthProvider.fromKey(await _storage.read(key: AuthSecretKey.lastSignInProvider));
    } catch (error, stackTrace) {
      developer.log(
        "Failed to read the last sign-in provider",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }
}
