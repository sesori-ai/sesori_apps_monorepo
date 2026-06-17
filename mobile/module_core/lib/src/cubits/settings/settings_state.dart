import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";

part "settings_state.freezed.dart";

/// Progress of the logout action initiated from the settings screen.
enum SettingsLogoutStatus { idle, inProgress, success, failure }

@Freezed()
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    /// The account this device is signed in as, or `null` when there is no
    /// authenticated session. Driven reactively by the auth state stream.
    required AuthUser? account,
    @Default(SettingsLogoutStatus.idle) SettingsLogoutStatus logoutStatus,
  }) = _SettingsState;
}
