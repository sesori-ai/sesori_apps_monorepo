import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";

/// Which theme the app renders in: the device setting, or a pinned choice.
enum AppearanceMode {
  light(storageValue: "light"),
  dark(storageValue: "dark"),
  system(storageValue: "system");

  const AppearanceMode({required this.storageValue});

  /// The persisted spelling of this mode. Pinned here rather than derived from
  /// the enum name so renaming a case cannot orphan a stored preference.
  final String storageValue;

  /// The mode persisted as [value], or `null` when it matches no known case.
  static AppearanceMode? tryParse({required String value}) {
    for (final mode in AppearanceMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return null;
  }
}

/// Persists the user's appearance choice across app runs.
///
/// The value is not a secret, but [SecureStorage] is the only key/value store
/// the shells already have, so it carries this preference too rather than
/// pulling in a second storage plugin. It survives logout by design: the theme
/// is a device preference, not account state.
@lazySingleton
class AppearanceStore {
  static const _storageKey = "appearance_mode";

  final SecureStorage _storage;

  AppearanceStore({required SecureStorage secureStorage}) : _storage = secureStorage;

  /// The stored appearance preference, or [AppearanceMode.system] when nothing
  /// was ever chosen, the stored value is unreadable, or storage fails. A
  /// theme preference is never worth failing startup over.
  Future<AppearanceMode> read() async {
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored == null) return AppearanceMode.system;

      final mode = AppearanceMode.tryParse(value: stored);
      if (mode == null) {
        logw("Ignoring an unknown stored appearance mode: $stored");
        return AppearanceMode.system;
      }
      return mode;
    } on Object catch (error, stackTrace) {
      logw("Failed to read the stored appearance mode", error, stackTrace);
      return AppearanceMode.system;
    }
  }

  /// Stores [mode] as the appearance preference. A failed write only costs the
  /// choice its persistence — the running app already switched — so it is
  /// logged rather than surfaced.
  Future<void> write({required AppearanceMode mode}) async {
    try {
      await _storage.write(key: _storageKey, value: mode.storageValue);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist the appearance mode", error, stackTrace);
    }
  }
}
