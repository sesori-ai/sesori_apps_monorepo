import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:device_info_plus/device_info_plus.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:integration_test/integration_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/analytics_runtime_bootstrap.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/di/register_module.dart";
import "package:sesori_mobile/core/platform/application_support_directory_client.dart";
import "package:sesori_mobile/core/platform/flutter_persistence_directory.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart" show AuthUser;

// Run only on a slot-owned simulator/emulator. Separate invocations deliberately
// leave native data in place: seed -> migrate -> reopen. Use --no-uninstall.
// Preserve existing slot records; fence all auth/analytics HTTP requests.
// The seeder uses the released ffa5935 plugin/keyspace/protection, not new-store
// writes. resetOnError is disabled so a broken native store cannot erase data.
enum _Phase() {
  disabled,
  seed,
  migrate,
  reopen,
}

const _phaseName = String.fromEnvironment("SESORI_NATIVE_PERSISTENCE_PHASE", defaultValue: "disabled");
const _scope = PersistenceScope.production;
const _legacyWriter = FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));
const _userId = "native-persistence-fixture";
const _unknownKey = "native-persistence-unrelated-fixture";
const _pluginKey = PluginPreferenceKey(bridgeId: "native-fixture/bridge:%");
const _analyticsKey = ProductAnalyticsPreferenceKey(userId: _userId);

// These are synthetic legacy bytes, never usable server credentials. Literal
// spellings are intentional fixtures of the released format, not a new encoder.
final _secrets = <String, String>{
  "access_token": "header.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.signature",
  "refresh_token": "native-fixture-refresh",
  "auth_user": jsonEncode(
    const AuthUser(
      id: _userId,
      provider: AuthProvider.github,
      providerUserId: "native-fixture-provider",
      providerUsername: null,
    ).toJson(),
  ),
  "pkce_verifier": "",
  "oauth_provider": "github",
  "oauth_session_token": "native-fixture-oauth-session",
  "oauth_session_expiry": "2099-01-01T00:00:00.000Z",
  "relay_room_key": base64Url.encode(List<int>.filled(32, 7)),
};
const _strings = <StringPersistenceKey, String>{
  StringPreferenceKey.appearanceMode: "dark",
  StringPreferenceKey.chatInputMode: "text_first",
  StringPreferenceKey.notificationPreferencesDeviceId: "123e4567-e89b-42d3-a456-426614174001",
  _pluginKey: "",
  _analyticsKey:
      '{"version":1,"kind":"pending_disable","userId":"native-persistence-fixture","revision":2,'
      '"userKey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",'
      '"operationId":"123e4567-e89b-42d3-a456-426614174000"}',
};
final _legacyValues = <String, String>{
  ..._secrets,
  for (final entry in _strings.entries) entry.key.storageKey: entry.value,
  BoolPreferenceKey.hasRegisteredBridges.storageKey: "false",
  _unknownKey: "retained",
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("native production migration $_phaseName", (tester) async {
    final phase = _Phase.values.byName(_phaseName);
    expect(phase, isNot(_Phase.disabled), reason: "Explicit fixture phase required; see the qualification guide");
    expect(Platform.isIOS || Platform.isAndroid, isTrue);
    final devices = DeviceInfoPlugin();
    final physical = Platform.isIOS
        ? (await devices.iosInfo).isPhysicalDevice
        : (await devices.androidInfo).isPhysicalDevice;
    expect(physical, isFalse, reason: "Only explicitly owned simulators/emulators are admitted");

    final module = _Module();
    final source = module.legacyNativeStorage();
    final master = module.masterKeyStore(scope: _scope);
    final directory = await FlutterPersistenceDirectory(directories: ApplicationSupportDirectoryClient()).resolve();
    final databaseFile = File("${directory.path}/${_scope.databaseFileName}");
    // Only a digest is persisted for the cross-process comparison, not native
    // plaintext. Existing slot records must survive the real one-way import.
    final fingerprintFile = File("${directory.path}/native-migration-fixture.sha256");

    if (phase == _Phase.seed) {
      // Never overwrite existing legacy values or an already created production
      // store. Development database/master are not touched.
      expect(databaseFile.existsSync(), isFalse, reason: "Production database already exists; refusing to reseed");
      expect(await master.read() == null, isTrue, reason: "Production master already exists; refusing to reseed");
      final existing = await source.readAll();
      for (final entry in _legacyValues.entries) {
        if (existing.containsKey(entry.key)) continue;
        await _legacyWriter.write(
          key: entry.key,
          value: entry.value,
          // Exercise enumeration/deletion across accessibility classes without
          // broadening or modifying any existing item's protection.
          iOptions: IOSOptions(
            accessibility: entry.key == _pluginKey.storageKey
                ? KeychainAccessibility.first_unlock
                : KeychainAccessibility.unlocked,
          ),
        );
      }
      final seeded = await source.readAll();
      final expected = {..._legacyValues, ...existing};
      expect(
        _fingerprint(values: seeded) == _fingerprint(values: expected),
        isTrue,
        reason: "Native seed preserves all existing values and enumerates both accessibility classes",
      );
      await fingerprintFile.writeAsString(_fingerprint(values: expected), flush: true);
      expect(databaseFile.existsSync(), isFalse);
      expect(await master.read() == null, isTrue);
      return;
    }

    if (phase == _Phase.migrate) {
      expect(_fingerprint(values: await source.readAll()) == await fingerprintFile.readAsString(), isTrue);
      expect(databaseFile.existsSync(), isFalse, reason: "Migration must start without a destination database");
    } else {
      expect(databaseFile.existsSync(), isTrue, reason: "Run migrate first; reopen must reuse its database");
    }

    getIt.skipDoubleRegistration = true;
    // Keep all persistence ports native. Only networking is fenced, so synthetic
    // auth cannot be submitted and analytics cannot contact a production sink.
    getIt.registerSingleton<http.Client>(
      MockClient((_) async => throw StateError("Unexpected fixture network request")),
    );
    if (phase == _Phase.reopen) getIt.registerSingleton<LegacyNativeStorage>(_NoLegacyReads());
    addTearDown(() async {
      await getIt.reset();
      getIt.skipDoubleRegistration = false;
    });

    await configureDependencies(
      scope: _scope,
      firebaseEnabled: false,
      createAnalyticsRuntimeBootstrap: ({required crawlGateService}) async {
        await _expectImportedValues(source: source, fingerprintFile: fingerprintFile);
        final remaining = await source.readAll();
        expect(remaining.containsKey(_unknownKey), isTrue);
        // The fixture-specific pending opt-out is materialized before analytics
        // admission, independently of any pre-existing slot account preferences.
        expect(
          await getIt<ProductAnalyticsPreferenceStorage>().read(userId: _userId),
          isA<StoredProductAnalyticsPendingDisable>(),
        );
        // configureDependencies resolves AnalyticsCrawlGateService (and its
        // AuthSession dependency) after migration, before invoking this callback.
        expect(await getIt<AuthSession>().restoreLocalSession(), isTrue);
        expect(getIt<AuthSession>().currentState, isA<AuthAuthenticated>());
        expect((await getIt<RoomKeyStorage>().getRoomKey())?.length, 32);
        final rows = await getIt<PersistenceDatabase>().select(getIt<PersistenceDatabase>().encryptedValues).get();
        expect(rows.length, _secrets.length);
        expect(await master.read() != null, isTrue);
        return AnalyticsRuntimeBootstrap(
          capability: const AnalyticsRuntimeCapability.disabled(
            reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
          ),
          crawlGate: Future.value(AnalyticsStoreCrawlGate.allow),
        );
      },
    );
    // Ordinary post-import writes must stay in Drift; old native items must not
    // return. Reopen performs these same assertions in a fresh OS process.
    final persister = getIt<PersisterRepository>();
    final original = await persister.readString(key: StringPreferenceKey.appearanceMode);
    expect(original, isNotNull);
    await persister.writeString(key: StringPreferenceKey.appearanceMode, value: "light");
    expect(await persister.readString(key: StringPreferenceKey.appearanceMode), "light");
    await persister.writeString(key: StringPreferenceKey.appearanceMode, value: original!);
    await _expectImportedValues(source: source, fingerprintFile: fingerprintFile);
  });
}

String _fingerprint({required Map<String, String> values}) =>
    sha256.convert(utf8.encode(jsonEncode(SplayTreeMap<String, String>.of(values)))).toString();

Future<void> _expectImportedValues({required LegacyNativeStorage source, required File fingerprintFile}) async {
  final database = getIt<PersistenceDatabase>();
  final remaining = await source.readAll();
  final imported = <String, String>{};
  for (final row in await database.select(database.stringValues).get()) {
    imported[row.key] = row.value;
  }
  for (final row in await database.select(database.boolValues).get()) {
    if (BoolPreferenceKey.values.any((key) => key.storageKey == row.key)) imported[row.key] = row.value.toString();
  }
  for (final row in await database.select(database.encryptedValues).get()) {
    final value = await getIt<SecureStorageRepository>().read(key: _FixtureSecretKey(storageKey: row.key));
    expect(value != null, isTrue, reason: row.key);
    imported[row.key] = value!;
  }
  expect(imported.keys.toSet().intersection(remaining.keys.toSet()), isEmpty, reason: "No copied native item remains");
  for (final key in _legacyValues.keys.where((key) => key != _unknownKey)) {
    expect(imported.containsKey(key), isTrue, reason: key);
  }
  // Recombine copied entries with untouched unknown entries. Compare a digest
  // so assertion output and the on-device witness contain no native plaintext.
  expect(
    _fingerprint(values: {...remaining, ...imported}) == await fingerprintFile.readAsString(),
    isTrue,
    reason: "Every source value survived import/reopen exactly, including scoped/unknown entries",
  );
}

class _Module() extends RegisterModule;

class _FixtureSecretKey({@override required final String storageKey}) implements SecretStorageKey;

class _NoLegacyReads() implements LegacyNativeStorage {
  @override
  Future<Map<String, String>> readAll() async => throw StateError("Completed migration must not enumerate legacy data");

  @override
  Future<void> delete({required String key}) async =>
      throw StateError("Completed migration must not delete legacy data");
}
