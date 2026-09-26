import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/analytics_runtime_bootstrap.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart" show AuthUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _MasterStore master;

  void registerPorts() {
    getIt.registerSingleton<http.Client>(MockClient((_) async => throw StateError("Unexpected network request")));
    getIt.registerSingleton<PersistenceDirectory>(_Directory(root: root));
    getIt.registerSingleton<MasterKeyStore>(master);
    getIt.registerSingleton<TemporaryDirectoryClient>(
      TemporaryDirectoryClient(provider: _TemporaryDirectory(root: root)),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp("sesori-admission-");
    master = _MasterStore();
    getIt.skipDoubleRegistration = true;
    registerPorts();
  });
  tearDown(() async {
    await getIt<LogSink>().flush();
    setLogSink(sink: const StdoutLogSink());
    await getIt.reset();
    getIt.skipDoubleRegistration = false;
    await root.delete(recursive: true);
  });

  test("development never constructs the legacy source and persists preferences without native access", () async {
    getIt.registerLazySingleton<LegacyNativeStorage>(() => throw StateError("Legacy source must not be constructed"));
    await configureDependencies(
      scope: PersistenceScope.development,
      firebaseEnabled: false,
      createAnalyticsRuntimeBootstrap: ({required crawlGateService}) async => _disabledBootstrap(),
    );
    expect(getIt.checkLazySingletonInstanceExists<LegacyNativeStorageMigrationService>(), isFalse);
    await getIt<AppearanceStore>().write(mode: AppearanceMode.dark);
    expect(await getIt<AppearanceStore>().read(), AppearanceMode.dark);
    expect(File("${root.path}/${PersistenceScope.development.databaseFileName}").existsSync(), isTrue);
    expect(File("${root.path}/${PersistenceScope.production.databaseFileName}").existsSync(), isFalse);
    expect(master.reads, 0);
    expect(master.writes, 0);
  });

  test("production import precedes auth, preferences and analytics; completed restart skips native source", () async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final token = "header.${base64Url.encode(utf8.encode('{"exp":$expiry}'))}.signature";
    final legacy = _LegacyStore();
    legacy.values.addAll({
      "access_token": token,
      "refresh_token": "fixture-refresh",
      "auth_user": jsonEncode(
        const AuthUser(
          id: "fixture-user",
          provider: AuthProvider.github,
          providerUserId: "fixture-provider",
          providerUsername: null,
        ).toJson(),
      ),
      "relay_room_key": base64Url.encode(List<int>.filled(32, 7)),
      "appearance_mode": "dark",
      "has_registered_bridges": "false",
      "product_analytics_preference_v1:fixture-user":
          '{"version":1,"kind":"pending_disable","userId":"fixture-user","revision":2,'
          '"userKey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",'
          '"operationId":"123e4567-e89b-42d3-a456-426614174000"}',
      "unrelated-item": "retained",
    });
    legacy.readGate = Completer<void>();
    getIt.registerSingleton<LegacyNativeStorage>(legacy);
    var analyticsCalls = 0;
    final configured = configureDependencies(
      scope: PersistenceScope.production,
      firebaseEnabled: false,
      createAnalyticsRuntimeBootstrap: ({required crawlGateService}) async {
        analyticsCalls++;
        expect(legacy.values, {"unrelated-item": "retained"});
        expect(await getIt<AppearanceStore>().read(), AppearanceMode.dark);
        expect(await getIt<PersisterRepository>().readBool(key: BoolPreferenceKey.hasRegisteredBridges), isFalse);
        expect(
          await getIt<ProductAnalyticsPreferenceStorage>().read(userId: "fixture-user"),
          isA<StoredProductAnalyticsPendingDisable>(),
        );
        expect(await getIt<AuthSession>().restoreLocalSession(), isTrue);
        expect((getIt<AuthSession>().currentState as AuthAuthenticated).user.id, "fixture-user");
        expect(await getIt<RoomKeyStorage>().getRoomKey(), List<int>.filled(32, 7));
        return _disabledBootstrap();
      },
    );
    await legacy.readStarted.future;
    expect(analyticsCalls, 0);
    expect(getIt.checkLazySingletonInstanceExists<AuthSession>(), isFalse);
    legacy.readGate!.complete();
    await configured;
    expect(analyticsCalls, 1);
    expect(master.reads, 1);
    expect(master.writes, 1);

    await getIt.reset();
    registerPorts();
    legacy.readError = StateError("Completed import must not enumerate again");
    getIt.registerSingleton<LegacyNativeStorage>(legacy);
    await configureDependencies(
      scope: PersistenceScope.production,
      firebaseEnabled: false,
      createAnalyticsRuntimeBootstrap: ({required crawlGateService}) async => _disabledBootstrap(),
    );
    expect(legacy.reads, 1);
    expect(await getIt<AppearanceStore>().read(), AppearanceMode.dark);
    expect(await getIt<AuthSession>().restoreLocalSession(), isTrue);
    expect(master.reads, 2);
    expect(master.writes, 1);
  });

  test("failed production enumeration resets storage before normal consumers start", () async {
    final cause = PlatformException(code: "fixture-denied", message: "fixture-native-denial", details: "status -25308");
    final legacy = _LegacyStore()..readError = cause;
    getIt.registerSingleton<LegacyNativeStorage>(legacy);
    legacy.values.addAll({"access_token": "stale-token", "appearance_mode": "dark"});
    var analyticsPrepared = false;
    await configureDependencies(
      scope: PersistenceScope.production,
      firebaseEnabled: false,
      createAnalyticsRuntimeBootstrap: ({required crawlGateService}) async {
        expect(legacy.values, isEmpty);
        expect(master.writes, 1);
        expect(await getIt<AuthSession>().restoreLocalSession(), isFalse);
        expect(await getIt<AppearanceStore>().read(), AppearanceMode.system);
        expect(await getIt<ProductAnalyticsPreferenceStorage>().read(userId: "fixture-user"), isNull);
        analyticsPrepared = true;
        return _disabledBootstrap();
      },
    );
    expect(analyticsPrepared, isTrue);
    expect(getIt.checkLazySingletonInstanceExists<MessageThumbnailCacheService>(), isTrue);
    expect(master.reads, 0);
    await getIt<LogSink>().flush();
    final log = await File("${root.path}/logs/app.log").readAsString();
    expect(log, contains("readSource"));
    expect(log, contains("fixture-denied"));
    expect(log, contains("fixture-native-denial"));
    expect(log, contains("status -25308"));
  });
}

AnalyticsRuntimeBootstrap _disabledBootstrap() => AnalyticsRuntimeBootstrap(
  capability: const AnalyticsRuntimeCapability.disabled(
    reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
  ),
  crawlGate: Future.value(AnalyticsStoreCrawlGate.allow),
);

class _Directory({required final Directory root}) implements PersistenceDirectory {
  @override
  Future<Directory> resolve() async => root;
}

class _TemporaryDirectory({required final Directory root}) implements TemporaryDirectoryProvider {
  @override
  Future<Directory> temporaryDirectory() async => root;
}

class _MasterStore() implements MasterKeyStore {
  String? value;
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write({required String value}) async {
    writes++;
    this.value = value;
  }
}

class _LegacyStore() implements LegacyNativeStorage {
  final Map<String, String> values = {};
  final readStarted = Completer<void>();
  Completer<void>? readGate;
  Object? readError;
  int reads = 0;

  @override
  Future<Map<String, String>> readAll() async {
    reads++;
    if (!readStarted.isCompleted) readStarted.complete();
    await readGate?.future;
    if (readError case final error?) throw error;
    return Map.of(values);
  }

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
