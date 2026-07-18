import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console, Log;
import "package:sesori_shared/sesori_shared.dart" show parseJwtUserId;

import "../foundation/app_onboarding_formatter.dart";
import "../repositories/app_client_status_repository.dart";
import "../repositories/app_onboarding_state_repository.dart";

class AppClientOnboardingService {
  AppClientOnboardingService({
    required AppClientStatusRepository statusRepository,
    required AppOnboardingStateRepository stateRepository,
    required AppOnboardingFormatter formatter,
  }) : _statusRepository = statusRepository,
       _stateRepository = stateRepository,
       _formatter = formatter;

  final AppClientStatusRepository _statusRepository;
  final AppOnboardingStateRepository _stateRepository;
  final AppOnboardingFormatter _formatter;

  Future<void> run({required String accessToken, required String authBackendUrl}) async {
    final userId = parseJwtUserId(accessToken);
    if (userId == null) {
      Log.w("Skipping app onboarding check: access token has no readable userId claim");
      return;
    }

    final marker = await _stateRepository.lookup(authBackendUrl: authBackendUrl, userId: userId);
    switch (marker) {
      case AppOnboardingStatePresent():
        return;
      case AppOnboardingStateAbsent():
        break;
      case AppOnboardingStateReadFailed(:final error, :final stackTrace):
        Log.w("Could not read app onboarding state; checking registration anyway", error, stackTrace);
    }

    final immediate = await _statusRepository.getStatus(accessToken: accessToken, wait: false);
    switch (immediate) {
      case AppClientRegistered():
        await _markCompleted(authBackendUrl: authBackendUrl, userId: userId);
        return;
      case AppClientStatusUnavailable(:final error, :final stackTrace):
        Log.w("Could not check Sesori app registration; continuing bridge startup", error, stackTrace);
        return;
      case AppClientAbsent():
        break;
    }

    Console.message("Open the Sesori app and sign in with this same account:");
    Console.message(_formatter.formatDestination());
    Console.message("Waiting up to 35 seconds for the app to connect...");

    final waited = await _statusRepository.getStatus(accessToken: accessToken, wait: true);
    switch (waited) {
      case AppClientRegistered():
        await _markCompleted(authBackendUrl: authBackendUrl, userId: userId);
        Console.message("Sesori app connected. Continuing bridge startup.");
      case AppClientAbsent():
        Console.message("No Sesori app connected yet; continuing bridge startup.");
      case AppClientStatusUnavailable(:final error, :final stackTrace):
        Log.w("Could not finish the Sesori app registration check; continuing bridge startup", error, stackTrace);
    }
  }

  Future<void> _markCompleted({required String authBackendUrl, required String userId}) async {
    try {
      await _stateRepository.markCompleted(authBackendUrl: authBackendUrl, userId: userId);
    } on Object catch (error, stackTrace) {
      Log.w("Could not save app onboarding completion; the next start may check again", error, stackTrace);
    }
  }
}
