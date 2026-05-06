import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "settings_state.dart";

class SettingsCubit extends Cubit<SettingsState> {
  final AuthSession _authSession;

  SettingsCubit({required AuthSession authSession}) : _authSession = authSession, super(const SettingsState.initial());

  Future<void> logout() async {
    if (state is SettingsLoggingOut) return;

    emit(const SettingsState.loggingOut());

    try {
      await _authSession.logoutCurrentDevice();
      if (isClosed) return;
      emit(const SettingsState.loggedOut());
    } catch (_) {
      if (isClosed) return;
      emit(const SettingsState.logoutFailed());
    }
  }
}
