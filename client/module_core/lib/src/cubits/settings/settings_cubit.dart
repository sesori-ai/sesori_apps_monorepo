import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";
import "../../services/notification_registration_service.dart";
import "../../services/product_analytics_service.dart";
import "settings_state.dart";

class SettingsCubit({
  required final AuthSession _authSession,
  required final NotificationRegistrationService _notificationRegistrationService,
  required final ProductAnalyticsService _productAnalyticsService,
}) extends Cubit<SettingsState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  this : super(SettingsState(account: _accountFrom(_authSession.currentState))) {
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
      try {
        await _productAnalyticsService.prepareForLogout();
      } catch (error, stackTrace) {
        logw("Failed to prepare product analytics for logout", error, stackTrace);
      }
      try {
        await _notificationRegistrationService.unregisterCurrentDevice();
      } catch (error, stackTrace) {
        logw("Failed to clean up push notifications during logout", error, stackTrace);
      }
      await _authSession.logoutCurrentDevice();
      if (isClosed) return;
      emit(state.copyWith(logoutStatus: SettingsLogoutStatus.success));
    } catch (_) {
      try {
        await _productAnalyticsService.resumeAfterFailedLogout();
      } catch (error, stackTrace) {
        logw("Failed to restore product analytics after logout failed", error, stackTrace);
      }
      try {
        await _notificationRegistrationService.resumeRegistrationAfterFailedLogout();
      } catch (error, stackTrace) {
        logw("Failed to restore push notifications after logout failed", error, stackTrace);
      }
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
