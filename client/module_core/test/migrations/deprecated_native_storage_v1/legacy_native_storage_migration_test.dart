import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/migrations/deprecated_native_storage_v1/foundation/keys/legacy_migration_key.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

import "migration_fixture.dart";

const _pluginKey = PluginPreferenceKey(bridgeId: "bridge /% ü");
const _analyticsKey = ProductAnalyticsPreferenceKey(userId: "user:/% ü");
const _pendingDisable =
    '{ "version":1,"kind":"pending_disable","userId":"user:/% ü",'
    ' "revision":7,"userKey":"fixture-user-key","operationId":"fixture-operation" }';
const _values = <String, String>{
  "access_token": "fixture-access",
  "refresh_token": "fixture-refresh",
  "auth_user": ' {"future":"opaque auth JSON"} ',
  "pkce_verifier": "",
  "oauth_provider": "github",
  "oauth_session_token": "fixture-oauth",
  "oauth_session_expiry": "2030-10-25T12:34:56.000Z",
  "relay_room_key": "AAE_Cw==",
  "appearance_mode": "",
  "chat_input_mode": "multiline",
  "notification_preferences_device_id_v1": "fixture-device-id",
  "has_registered_bridges": "false",
  "new_session_plugin_bridge%20%2F%25%20%C3%BC": "future-plugin",
  "new_session_plugin_second_bridge": "another-plugin",
  "product_analytics_preference_v1:user:/% ü": _pendingDisable,
  "product_analytics_preference_v1:second-user": "opaque future JSON",
  "other.native.item": "keep-unknown",
  "client-master-key-v1-production": "keep-native-master-item",
};
const _unknown = <String, String>{
  "other.native.item": "keep-unknown",
  "client-master-key-v1-production": "keep-native-master-item",
};

void main() {
  test("imports the closed inventory, exact payloads and scoped identities through lazy shared DI", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    expect(fixture.master.reads, 0);
    expect(fixture.source.reads, 0);
    // Cleanup cannot begin until every destination category has committed.
    fixture.source.beforeDelete = () async {
      expect(await fixture.secrets.read(key: CoreSecretKey.relayRoomKey), _values["relay_room_key"]);
      expect(await fixture.persister.readString(key: _analyticsKey), _pendingDisable);
      expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), false);
      expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    };

    await _migrate(service: fixture.service);
    expect(fixture.master.reads, 1);
    expect(fixture.master.writes, 1);
    expect(fixture.source.values, _unknown);
    expect(fixture.source.deleted.toSet(), _values.keys.toSet().difference(_unknown.keys.toSet()));
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    await fixture.reopen();

    for (final key in <SecretStorageKey>[...AuthSecretKey.values, ...CoreSecretKey.values]) {
      expect(await fixture.secrets.read(key: key), _values[key.storageKey]);
    }
    for (final key in StringPreferenceKey.values) {
      expect(await fixture.persister.readString(key: key), _values[key.storageKey]);
    }
    expect(await fixture.persister.readString(key: _pluginKey), "future-plugin");
    expect(
      await fixture.persister.readString(key: const PluginPreferenceKey(bridgeId: "second_bridge")),
      "another-plugin",
    );
    expect(await fixture.persister.readString(key: _analyticsKey), _pendingDisable);
    expect(
      await fixture.persister.readString(key: const ProductAnalyticsPreferenceKey(userId: "second-user")),
      "opaque future JSON",
    );
    expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), false);
    expect((await fixture.database.select(fixture.database.encryptedValues).get()).length, 8);
    final plaintext = await fixture.database.select(fixture.database.stringValues).get();
    expect(plaintext.any((row) => row.value == "fixture-access"), false);
    expect(fixture.master.reads, 2);
    expect(fixture.master.writes, 1);
  });

  test("completion skips even a failing legacy source on a cold relaunch", () async {
    final fixture = await MigrationFixture.create(values: const {"appearance_mode": "dark"});
    addTearDown(fixture.dispose);
    await _migrate(service: fixture.service);
    await fixture.reopen();
    fixture.source.readFailure = (error: StateError("must not read"), stackTrace: StackTrace.current);
    await _migrate(service: fixture.service);
    expect(fixture.source.reads, 1);
    expect(fixture.source.deleted, ["appearance_mode"]);
    expect(fixture.master.reads, 0);
  });

  test("empty source preserves absence and never unlocks; unrelated native values survive", () async {
    final fixture = await MigrationFixture.create(values: _unknown);
    addTearDown(fixture.dispose);
    await _migrate(service: fixture.service);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), isNull);
    expect(await fixture.persister.readString(key: StringPreferenceKey.appearanceMode), isNull);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(fixture.source.values, _unknown);
    expect(fixture.source.deleted, isEmpty);
    expect(fixture.master.reads, 0);
  });

  test("true boolean is imported without changing other absent values", () async {
    final fixture = await MigrationFixture.create(values: const {"has_registered_bridges": "true"});
    addTearDown(fixture.dispose);
    await _migrate(service: fixture.service);
    expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), true);
    expect(await fixture.persister.readString(key: StringPreferenceKey.chatInputMode), isNull);
    expect(fixture.master.reads, 0);
  });

  test("completion read failure stops before legacy access", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    final service = fixture.service;
    await fixture.database.customStatement("DROP TABLE bool_values");
    await expectLater(
      _migrate(service: service),
      throwsA(_failure(operation: LegacyStorageMigrationOperation.readCompletion)),
    );
    expect(fixture.source.reads, 0);
    expect(fixture.source.deleted, isEmpty);
  });

  test("native failure retains exact cause/stack without exposing its payload", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    final cause = StateError("sensitive-source-payload");
    final trace = StackTrace.fromString("fixture native read stack");
    fixture.source.readFailure = (error: cause, stackTrace: trace);
    try {
      await _migrate(service: fixture.service);
      fail("Expected migration failure");
    } on LegacyStorageMigrationException catch (error, stackTrace) {
      expect(error.operation, LegacyStorageMigrationOperation.readSource);
      expect(error.innerError, same(cause));
      expect(error.innerStackTrace, same(trace));
      expect(stackTrace.toString(), trace.toString());
      expect(error.toString(), isNot(contains("sensitive-source-payload")));
    }
    expect(fixture.source.values, _values);
    expect(fixture.source.deleted, isEmpty);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    expect(fixture.master.reads, 0);
  });

  test("malformed known boolean aborts classification before even an earlier secret is copied", () async {
    final fixture = await MigrationFixture.create(
      values: const {
        "access_token": "fixture-access",
        "has_registered_bridges": "not-a-bool",
      },
    );
    addTearDown(fixture.dispose);
    await expectLater(
      _migrate(service: fixture.service),
      throwsA(
        _failure(operation: LegacyStorageMigrationOperation.readSource)
            .having((e) => e.innerError, "cause", isFormatException),
      ),
    );
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    expect(fixture.source.values.length, 2);
    expect(fixture.source.deleted, isEmpty);
    expect(fixture.master.reads, 0);
  });

  test("denied master save leaves every native source entry intact", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    fixture.master.writeFailure = StateError("fixture native denial");
    await expectLater(
      _migrate(service: fixture.service),
      throwsA(_failure(operation: LegacyStorageMigrationOperation.copyValues)),
    );
    expect(fixture.source.values, _values);
    expect(fixture.source.deleted, isEmpty);
    expect(await fixture.database.select(fixture.database.encryptedValues).get(), isEmpty);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    fixture.master.writeFailure = null;
    await fixture.reopen();
    await _migrate(service: fixture.service);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), "fixture-access");
  });

  test("mid-copy SQL failure retains partial committed rows and all source until relaunch", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    await fixture.database.customStatement("""
      CREATE TEMP TRIGGER reject_copy BEFORE INSERT ON string_values
      WHEN NEW.key = 'chat_input_mode' BEGIN SELECT RAISE(FAIL, 'fixture copy failure'); END;
    """);
    await expectLater(
      _migrate(service: fixture.service),
      throwsA(_failure(operation: LegacyStorageMigrationOperation.copyValues)),
    );
    expect(await fixture.secrets.read(key: AuthSecretKey.refreshToken), "fixture-refresh");
    expect(await fixture.persister.readString(key: StringPreferenceKey.appearanceMode), "");
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    expect(fixture.source.values, _values);
    expect(fixture.source.deleted, isEmpty);
    await fixture.reopen();
    await _migrate(service: fixture.service);
    expect(await fixture.persister.readString(key: StringPreferenceKey.chatInputMode), "multiline");
    expect(fixture.source.values, _unknown);
    expect(fixture.master.writes, 1);
  });

  test("partial cleanup merges remaining source without erasing already committed absent entries", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    fixture.source.deleteFailure = (key: "refresh_token", error: StateError("fixture cleanup denied"));
    await expectLater(
      _migrate(service: fixture.service),
      throwsA(_failure(operation: LegacyStorageMigrationOperation.deleteSource)),
    );
    expect(fixture.source.values.containsKey("access_token"), false);
    expect(fixture.source.values["refresh_token"], "fixture-refresh");
    expect(await fixture.persister.readString(key: _analyticsKey), _pendingDisable);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    fixture.source.deleteFailure = null;
    await fixture.reopen();
    await _migrate(service: fixture.service);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), "fixture-access");
    expect(await fixture.secrets.read(key: AuthSecretKey.refreshToken), "fixture-refresh");
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(fixture.source.values, _unknown);
    expect(fixture.master.writes, 1);
  });

  test("marker failure after cleanup retries with no source but retains the entire destination", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    await fixture.database.customStatement("""
      CREATE TEMP TRIGGER reject_marker BEFORE INSERT ON bool_values
      WHEN NEW.key = 'deprecated_native_storage_v1_completed'
      BEGIN SELECT RAISE(FAIL, 'fixture marker failure'); END;
    """);
    await expectLater(
      _migrate(service: fixture.service),
      throwsA(_failure(operation: LegacyStorageMigrationOperation.writeCompletion)),
    );
    expect(fixture.source.values, _unknown);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    await fixture.reopen();
    await _migrate(service: fixture.service);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), "fixture-access");
    expect(await fixture.persister.readString(key: _analyticsKey), _pendingDisable);
    expect(await fixture.persister.readString(key: _pluginKey), "future-plugin");
    expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), false);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(fixture.source.deleted.length, _values.length - _unknown.length);
    expect(fixture.master.writes, 1);
  });
}

TypeMatcher<LegacyStorageMigrationException> _failure({required LegacyStorageMigrationOperation operation}) =>
    isA<LegacyStorageMigrationException>().having((e) => e.operation, "operation", operation);

Future<void> _migrate({required LegacyNativeStorageMigrationService service}) {
  // Intentional coverage of the temporary entry point; removed with the importer.
  return service.migrate();
}
