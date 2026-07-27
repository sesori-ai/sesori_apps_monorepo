import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show parseJwtUserId;

import "../repositories/app_client_status_repository.dart";
import "../repositories/app_onboarding_state_repository.dart";

enum AppClientOnboardingDecision { skip, prompt }

class AppClientOnboardingService {
  AppClientOnboardingService({
    required AppClientStatusRepository statusRepository,
    required AppOnboardingStateRepository stateRepository,
  }) : _statusRepository = statusRepository,
       _stateRepository = stateRepository;

  final AppClientStatusRepository _statusRepository;
  final AppOnboardingStateRepository _stateRepository;

  Future<AppClientOnboardingDecision> prepare({
    required String accessToken,
    required String authBackendUrl,
  }) async {
    try {
      return await _prepare(accessToken: accessToken, authBackendUrl: authBackendUrl);
    } on Object catch (error, stackTrace) {
      Log.w("Could not prepare Sesori app onboarding; continuing bridge startup", error, stackTrace);
      return AppClientOnboardingDecision.skip;
    }
  }

  Future<AppClientOnboardingDecision> _prepare({
    required String accessToken,
    required String authBackendUrl,
  }) async {
    final userId = parseJwtUserId(accessToken);
    if (userId == null) {
      Log.w("Skipping app onboarding check: access token has no readable userId claim");
      return AppClientOnboardingDecision.skip;
    }

    final marker = await _stateRepository.lookup(authBackendUrl: authBackendUrl, userId: userId);
    switch (marker) {
      case AppOnboardingStatePresent():
        return AppClientOnboardingDecision.skip;
      case AppOnboardingStateAbsent():
        break;
      case AppOnboardingStateReadFailed(:final error, :final stackTrace):
        Log.w("Could not read app onboarding state; checking registration anyway", error, stackTrace);
    }

    final immediate = await _statusRepository.getStatus(accessToken: accessToken);
    switch (immediate) {
      case AppClientRegistered():
        await _markCompleted(authBackendUrl: authBackendUrl, userId: userId);
        return AppClientOnboardingDecision.skip;
      case AppClientStatusUnavailable(:final error, :final stackTrace):
        Log.w("Could not check Sesori app registration; continuing bridge startup", error, stackTrace);
        return AppClientOnboardingDecision.skip;
      case AppClientAbsent():
        return AppClientOnboardingDecision.prompt;
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
