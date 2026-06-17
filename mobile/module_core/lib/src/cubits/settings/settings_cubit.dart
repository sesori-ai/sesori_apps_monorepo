import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";

import "settings_state.dart";

class SettingsCubit extends Cubit<SettingsState> {
  final AuthSession _authSession;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  SettingsCubit({required AuthSession authSession})
    : _authSession = authSession,
      super(SettingsState(account: _accountFrom(authSession.currentState))) {
    // Keep the signed-in account in sync: the session is restored
    // asynchronously on launch, so the account may resolve after the cubit is
    // first constructed. Initial value comes from currentState above so the UI
    // renders without a flash.
    _subscriptions.add(
      _authSession.authStateStream.listen((authState) {
        if (isClosed) return;
        emit(state.copyWith(account: _accountFrom(authState)));
      }),
    );
  }

  static AuthUser? _accountFrom(AuthState authState) => switch (authState) {
    AuthAuthenticated(:final user) => user,
    AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
  };

  Future<void> logout() async {
    if (state.logoutStatus == SettingsLogoutStatus.inProgress) return;

    emit(state.copyWith(logoutStatus: SettingsLogoutStatus.inProgress));

    try {
      await _authSession.logoutCurrentDevice();
      if (isClosed) return;
      emit(state.copyWith(logoutStatus: SettingsLogoutStatus.success));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(logoutStatus: SettingsLogoutStatus.failure));
    }
  }

  @override
  Future<void> close() {
    _subscriptions.dispose();
    return super.close();
  }
}
