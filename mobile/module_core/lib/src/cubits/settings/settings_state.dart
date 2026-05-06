import "package:freezed_annotation/freezed_annotation.dart";

part "settings_state.freezed.dart";

@Freezed()
sealed class SettingsState with _$SettingsState {
  const factory SettingsState.initial() = SettingsInitial;

  const factory SettingsState.loggedOut() = SettingsLoggedOut;
}
