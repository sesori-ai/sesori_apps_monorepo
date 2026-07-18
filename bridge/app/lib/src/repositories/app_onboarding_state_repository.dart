import "dart:convert";

import "package:crypto/crypto.dart" show sha256;

import "../api/app_onboarding_state_storage.dart";

sealed class AppOnboardingStateLookup {
  const AppOnboardingStateLookup();
}

final class AppOnboardingStatePresent extends AppOnboardingStateLookup {
  const AppOnboardingStatePresent();
}

final class AppOnboardingStateAbsent extends AppOnboardingStateLookup {
  const AppOnboardingStateAbsent();
}

final class AppOnboardingStateReadFailed extends AppOnboardingStateLookup {
  const AppOnboardingStateReadFailed({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;
}

class AppOnboardingStateRepository {
  AppOnboardingStateRepository({required AppOnboardingStateStorage storage}) : _storage = storage;

  final AppOnboardingStateStorage _storage;

  Future<AppOnboardingStateLookup> lookup({
    required String authBackendUrl,
    required String userId,
  }) async {
    try {
      final exists = await _storage.markerExists(
        key: _markerKey(authBackendUrl: authBackendUrl, userId: userId),
      );
      return exists ? const AppOnboardingStatePresent() : const AppOnboardingStateAbsent();
    } on Object catch (error, stackTrace) {
      return AppOnboardingStateReadFailed(error: error, stackTrace: stackTrace);
    }
  }

  Future<void> markCompleted({
    required String authBackendUrl,
    required String userId,
  }) {
    return _storage.writeMarker(
      key: _markerKey(authBackendUrl: authBackendUrl, userId: userId),
    );
  }

  Future<void> clearAll() => _storage.clearAll();

  String _markerKey({required String authBackendUrl, required String userId}) {
    final normalizedAuthBackend = authBackendUrl.replaceFirst(RegExp(r"/+$"), "");
    return sha256.convert(utf8.encode(jsonEncode([normalizedAuthBackend, userId]))).toString();
  }
}
