import "dart:io";

import "package:sesori_bridge/src/api/app_onboarding_state_storage.dart";
import "package:sesori_bridge/src/repositories/app_onboarding_state_repository.dart";
import "package:test/test.dart";

void main() {
  group("AppOnboardingStateRepository", () {
    late _MemoryAppOnboardingStateStorage storage;
    late AppOnboardingStateRepository repository;

    setUp(() {
      storage = _MemoryAppOnboardingStateStorage();
      repository = AppOnboardingStateRepository(storage: storage);
    });

    test("maps missing and matching pair markers", () async {
      expect(
        await repository.lookup(authBackendUrl: "https://auth-a.test", userId: "user-a"),
        isA<AppOnboardingStateAbsent>(),
      );

      await repository.markCompleted(authBackendUrl: "https://auth-a.test", userId: "user-a");

      expect(
        await repository.lookup(authBackendUrl: "https://auth-a.test/", userId: "user-a"),
        isA<AppOnboardingStatePresent>(),
      );
    });

    test("retains independent opaque markers for backend and account pairs", () async {
      await repository.markCompleted(authBackendUrl: "https://auth-a.test", userId: "user-a");
      await repository.markCompleted(authBackendUrl: "https://auth-b.test", userId: "user-a");
      await repository.markCompleted(authBackendUrl: "https://auth-a.test", userId: "user-b");

      expect(storage.keys, hasLength(3));
      for (final key in storage.keys) {
        expect(key, matches(RegExp(r"^[0-9a-f]{64}$")));
        expect(key, isNot(contains("auth")));
        expect(key, isNot(contains("user")));
      }
      expect(
        await repository.lookup(authBackendUrl: "https://auth-a.test", userId: "user-a"),
        isA<AppOnboardingStatePresent>(),
      );
      expect(
        await repository.lookup(authBackendUrl: "https://auth-b.test", userId: "user-a"),
        isA<AppOnboardingStatePresent>(),
      );
    });

    test("maps marker read failures without treating them as present", () async {
      const error = FileSystemException("unreadable marker directory");
      storage.readError = error;

      final result = await repository.lookup(authBackendUrl: "https://auth.test", userId: "user-a");

      expect(result, isA<AppOnboardingStateReadFailed>());
      expect((result as AppOnboardingStateReadFailed).error, same(error));
    });

    test("clears every retained pair marker", () async {
      await repository.markCompleted(authBackendUrl: "https://auth-a.test", userId: "user-a");
      await repository.markCompleted(authBackendUrl: "https://auth-b.test", userId: "user-b");

      await repository.clearAll();

      expect(storage.keys, isEmpty);
    });
  });
}

class _MemoryAppOnboardingStateStorage implements AppOnboardingStateStorage {
  final Set<String> keys = {};
  Object? readError;

  @override
  Future<bool> markerExists({required String key}) async {
    if (readError != null) throw readError!;
    return keys.contains(key);
  }

  @override
  Future<void> writeMarker({required String key}) async {
    keys.add(key);
  }

  @override
  Future<void> clearAll() async {
    keys.clear();
  }
}
