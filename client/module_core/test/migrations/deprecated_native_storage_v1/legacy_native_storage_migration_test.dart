import "dart:async";

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
};

void main() {
  late _RecordingSink logs;
  setUp(() {
    logs = _RecordingSink();
    setLogSink(sink: logs);
  });
  tearDown(() => setLogSink(sink: const StdoutLogSink()));

  test("successful import preserves payloads/scoped identities and only deletes copied native entries", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    expect(fixture.master.reads, 0);
    expect(fixture.source.reads, 0);
    fixture.source.beforeDelete = () async {
      expect(await fixture.secrets.read(key: CoreSecretKey.relayRoomKey), _values["relay_room_key"]);
      expect(await fixture.persister.readString(key: _analyticsKey), _pendingDisable);
      expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), false);
      expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), isNull);
    };
    await fixture.service.migrate();
    expect(fixture.master.reads, 1);
    expect(fixture.master.writes, 1);
    expect(fixture.source.values, {"other.native.item": "keep-unknown"});
    expect(fixture.source.clears, 0);
    expect(fixture.source.deleted.toSet(), _values.keys.toSet()..remove("other.native.item"));
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
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(await fixture.database.select(fixture.database.encryptedValues).get(), hasLength(8));
    expect(logs.records, isEmpty);
  });

  test("restart after process interruption merges remaining source without clearing committed rows", () async {
    final fixture = await MigrationFixture.create(values: const {"access_token": "remaining-native-token"});
    addTearDown(fixture.dispose);
    await fixture.secrets.write(key: AuthSecretKey.refreshToken, value: "already-copied-token");
    await fixture.persister.writeString(key: StringPreferenceKey.appearanceMode, value: "dark");
    await fixture.reopen();
    await fixture.service.migrate();
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), "remaining-native-token");
    expect(await fixture.secrets.read(key: AuthSecretKey.refreshToken), "already-copied-token");
    expect(await fixture.persister.readString(key: StringPreferenceKey.appearanceMode), "dark");
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(fixture.source.clears, 0);
    expect(logs.records, isEmpty);
  });

  test("completion skips a failing source on cold relaunch", () async {
    final fixture = await MigrationFixture.create(values: const {"appearance_mode": "dark"});
    addTearDown(fixture.dispose);
    await fixture.service.migrate();
    await fixture.reopen();
    fixture.source.readFailure = (error: StateError("must not read"), stackTrace: StackTrace.current);
    await fixture.service.migrate();
    expect(fixture.source.reads, 1);
    expect(fixture.source.clears, 0);
    expect(fixture.master.reads, 0);
  });

  test("empty source preserves absence and never unlocks; true bool remains a real value", () async {
    final fixture = await MigrationFixture.create(values: const {"other.native.item": "retained"});
    addTearDown(fixture.dispose);
    await fixture.service.migrate();
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), isNull);
    expect(fixture.source.values, {"other.native.item": "retained"});
    expect(fixture.master.reads, 0);
    final boolean = await MigrationFixture.create(values: const {"has_registered_bridges": "true"});
    addTearDown(boolean.dispose);
    await boolean.service.migrate();
    expect(await boolean.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), true);
  });

  for (final operation in [
    LegacyStorageMigrationOperation.readSource,
    LegacyStorageMigrationOperation.copyValues,
    LegacyStorageMigrationOperation.deleteSource,
    LegacyStorageMigrationOperation.writeCompletion,
  ]) {
    test("$operation failure resets old/partial data, continues and permits fresh auth", () async {
      final fixture = await MigrationFixture.create(values: _values);
      addTearDown(fixture.dispose);
      switch (operation) {
        case LegacyStorageMigrationOperation.readSource:
          fixture.source.readFailure = (error: StateError("fixture native failure"), stackTrace: StackTrace.current);
        case LegacyStorageMigrationOperation.copyValues:
          await fixture.database.customStatement("""
            CREATE TEMP TRIGGER reject_copy BEFORE INSERT ON string_values
            WHEN NEW.key = 'chat_input_mode' BEGIN SELECT RAISE(FAIL, 'fixture copy failure'); END;
          """);
        case LegacyStorageMigrationOperation.deleteSource:
          fixture.source.deleteFailure = (key: "refresh_token", error: StateError("fixture cleanup denied"));
        case LegacyStorageMigrationOperation.writeCompletion:
          // Fail just the first marker. Its trigger vanishes when reset removes
          // the appearance row, so the subsequent recovery marker can commit.
          await fixture.database.customStatement("""
            CREATE TEMP TRIGGER reject_marker BEFORE INSERT ON bool_values
            WHEN NEW.key = 'deprecated_native_storage_v1_completed'
            AND EXISTS (SELECT 1 FROM string_values)
            BEGIN SELECT RAISE(FAIL, 'fixture marker failure'); END;
          """);
        case LegacyStorageMigrationOperation.readCompletion:
        case LegacyStorageMigrationOperation.resetSecrets:
        case LegacyStorageMigrationOperation.clearPreferences:
        case LegacyStorageMigrationOperation.clearSource:
        case LegacyStorageMigrationOperation.markReset:
          fail("Unexpected fixture operation");
      }
      await fixture.service.migrate();
      expect(fixture.source.values, isEmpty);
      expect(fixture.source.clears, 1);
      expect(await fixture.database.select(fixture.database.encryptedValues).get(), isEmpty);
      expect(await fixture.database.select(fixture.database.stringValues).get(), isEmpty);
      expect(await fixture.persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges), isNull);
      expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
      expect(logs.records.single.diagnosticError, contains(operation.name));
      await fixture.secrets.write(key: AuthSecretKey.accessToken, value: "new-login");
      await fixture.reopen();
      final reads = fixture.source.reads;
      await fixture.service.migrate();
      expect(fixture.source.reads, reads);
      expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), "new-login");
    });
  }

  test("malformed bool logs the original stack safely, clears data and continues", () async {
    final fixture = await MigrationFixture.create(
      values: const {"access_token": "private", "has_registered_bridges": "private-payload"},
    );
    addTearDown(fixture.dispose);
    await fixture.service.migrate();
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(fixture.source.values, isEmpty);
    expect(fixture.master.reads, 0);
    expect(fixture.master.writes, 1);
    expect(logs.records.single.diagnosticError, contains("readSource"));
    expect(logs.records.single.formatted, isNot(contains("private-payload")));
    expect(logs.records.single.stackTrace, isNotNull);
  });

  test("denied source clearing is logged but completion fences off stale native auth", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    fixture.source.readFailure = (error: StateError("denied read"), stackTrace: StackTrace.current);
    fixture.source.clearFailure = StateError("denied clear");
    await fixture.service.migrate();
    expect(fixture.source.values, _values);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(logs.records.map((e) => e.diagnosticError), [contains("readSource"), contains("clearSource")]);
    await fixture.reopen();
    fixture.source.readFailure = null;
    final reads = fixture.source.reads;
    await fixture.service.migrate();
    expect(fixture.source.reads, reads);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
  });

  test("persistent marker/primitive failure stays observable without stopping other cleanup", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    await fixture.database.customStatement("DROP TABLE bool_values");
    await fixture.service.migrate();
    expect(fixture.source.reads, 0);
    expect(fixture.source.clears, 1);
    expect(fixture.source.values, isEmpty);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(logs.records.map((e) => e.diagnosticError), [
      contains("readCompletion"),
      contains("clearPreferences"),
      contains("markReset"),
    ]);
  });

  test("denied key reset remains cached but cleanup and logged-out reads continue", () async {
    final fixture = await MigrationFixture.create(values: _values);
    addTearDown(fixture.dispose);
    fixture.master.writeFailure = StateError("fixture native denial");
    await fixture.service.migrate();
    expect(fixture.source.values, isEmpty);
    expect(await fixture.secrets.read(key: AuthSecretKey.accessToken), isNull);
    expect(await fixture.persister.readBool(key: LegacyMigrationKey.completed), true);
    expect(logs.records.map((e) => e.diagnosticError), [contains("copyValues"), contains("resetSecrets")]);
    await expectLater(
      fixture.secrets.write(key: AuthSecretKey.accessToken, value: "new"),
      throwsA(isA<ParallelWaitError<Object?, Object?>>()),
    );
  });
}

class _RecordingSink() implements LogSink {
  final records = <LogRecord>[];
  @override
  void write({required LogRecord record}) => records.add(record);
  @override
  Future<void> flush() async {}
}
