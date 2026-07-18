import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console, Log;
import "package:sesori_shared/sesori_shared.dart" show parseJwtUserId;

import "../auth/token_refresher.dart";
import "../foundation/app_onboarding_formatter.dart";
import "../repositories/app_client_status_repository.dart";
import "../repositories/app_onboarding_state_repository.dart";

class AppClientOnboardingService {
  AppClientOnboardingService({
    required AppClientStatusRepository statusRepository,
    required AppOnboardingStateRepository stateRepository,
    required AppOnboardingFormatter formatter,
    required TokenRefresher tokenRefresher,
  }) : _statusRepository = statusRepository,
       _stateRepository = stateRepository,
       _formatter = formatter,
       _tokenRefresher = tokenRefresher;

  static const Duration _failureRetryDelay = Duration(seconds: 5);

  final AppClientStatusRepository _statusRepository;
  final AppOnboardingStateRepository _stateRepository;
  final AppOnboardingFormatter _formatter;
  final TokenRefresher _tokenRefresher;

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

    Console.message("");
    Console.message("Connect the Sesori mobile app to continue");
    Console.message("");
    Console.message(
      "Use the QR code or link below to install or open Sesori, then sign in with this same account.",
    );
    Console.message("");
    Console.message(_formatter.formatDestination());
    Console.message("");
    Console.message("Waiting for the Sesori mobile app to connect...");
    Console.message("Bridge startup is paused and will continue automatically once connected.");

    var waitFailureReported = false;
    while (true) {
      final String pollingAccessToken;
      try {
        pollingAccessToken = await _tokenRefresher.getAccessToken();
      } on Object catch (error, stackTrace) {
        if (!waitFailureReported) {
          Log.w(
            "Could not refresh authentication while waiting for the Sesori app; retrying",
            error,
            stackTrace,
          );
          waitFailureReported = true;
        }
        await Future<void>.delayed(_failureRetryDelay);
        continue;
      }

      final waited = await _statusRepository.getStatus(accessToken: pollingAccessToken, wait: true);
      switch (waited) {
        case AppClientRegistered():
          await _markCompleted(authBackendUrl: authBackendUrl, userId: userId);
          Console.message("");
          Console.message("Sesori mobile app connected. Continuing bridge startup.");
          return;
        case AppClientAbsent():
          waitFailureReported = false;
        case AppClientStatusUnavailable(:final error, :final stackTrace):
          if (!waitFailureReported) {
            Log.w(
              "Could not check Sesori app registration; bridge startup remains paused and the check will retry",
              error,
              stackTrace,
            );
            waitFailureReported = true;
          }
          await Future<void>.delayed(_failureRetryDelay);
      }
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
