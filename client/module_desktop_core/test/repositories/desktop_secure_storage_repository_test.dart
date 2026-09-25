import "dart:async";
import "dart:convert";

import "package:drift/native.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

import "../fixtures/desktop_storage_fixture.dart";

void main() {
  const first = FixtureSecretKey(storageKey: "fixture.first");
  const second = FixtureSecretKey(storageKey: "fixture.second");
  late DesktopPersistenceDatabase database;
  late DesktopPrimitiveStorageApi primitive;
  late DesktopSecureStorageApi api;
  late DesktopStorageCipher cipher;
  late FixtureMasterKeyStore native;
  late DesktopSecureStorageRepository repository;

  setUp(() {
    database = DesktopPersistenceDatabase(executor: NativeDatabase.memory());
    primitive = DesktopPrimitiveStorageApi(database: database);
    native = FixtureMasterKeyStore(value: null);
    api = DesktopSecureStorageApi(database: database, masterKeyStore: native);
    cipher = DesktopStorageCipher(scope: DesktopStorageScope.development);
    repository = DesktopSecureStorageRepository(storageApi: api, cipher: cipher);
  });

  tearDown(() => database.close());

  test("missing reads and deletes require no native key", () async {
    expect(await repository.read(key: first), isNull);
    await repository.delete(key: first);
    expect(native.reads, 0);
    expect(native.writes, 0);
  });

  test("plaintext-only databases can create a key; primitives remain independent", () async {
    await primitive.writeString(key: "theme", value: "dark");
    await primitive.writeBool(key: "registered", value: false);
    expect(native.reads, 0);

    await repository.write(key: first, value: "fixture credential");
    expect(await repository.read(key: first), "fixture credential");
    expect(base64Decode(native.storedValue!), hasLength(32));
    expect(native.reads, 1);
    expect(native.writes, 1);
    expect(await primitive.readString(key: "theme"), "dark");
    expect(await primitive.readBool(key: "registered"), isFalse);
    expect(await database.select(database.encryptedValues).get(), hasLength(1));
  });

  test("concurrent writes share pending initialization without blocking preferences", () async {
    final unlock = Completer<String?>();
    native.readResult = unlock.future;
    final keys = List.generate(12, (index) => FixtureSecretKey(storageKey: "fixture.$index"));
    final writes = keys.map((key) => repository.write(key: key, value: "value:${key.storageKey}")).toList();
    await native.readStarted.future;
    expect(native.reads, 1);
    expect(native.writes, 0);

    await primitive.writeString(key: "theme", value: "light");
    expect(await primitive.readString(key: "theme"), "light");
    unlock.complete(null);
    await Future.wait(writes);

    expect(native.reads, 1);
    expect(native.writes, 1);
    for (final key in keys) {
      expect(await repository.read(key: key), "value:${key.storageKey}");
    }
    expect(native.reads, 1);
  });

  test("ciphertext is not committed before the new native key is saved", () async {
    final saved = Completer<void>();
    native.writeCompletion = saved.future;
    final write = repository.write(key: first, value: "fixture credential");
    await native.writeStarted.future;
    expect(native.storedValue, isNull);
    expect(await api.hasEncryptedValues(), isFalse);
    expect(await repository.read(key: first), isNull);

    saved.complete();
    await write;
    expect(await repository.read(key: first), "fixture credential");
  });

  test("cold concurrent reads share one native load and never rewrite its key", () async {
    await repository.write(key: first, value: "first value");
    await repository.write(key: second, value: "second value");
    final coldNative = FixtureMasterKeyStore(value: native.storedValue);
    final unlock = Completer<String?>();
    coldNative.readResult = unlock.future;
    final cold = DesktopSecureStorageRepository(
      storageApi: DesktopSecureStorageApi(database: database, masterKeyStore: coldNative),
      cipher: cipher,
    );
    final reads = [cold.read(key: first), cold.read(key: second)];
    await coldNative.readStarted.future;
    expect(coldNative.reads, 1);
    unlock.complete(coldNative.storedValue);
    expect(await Future.wait(reads), ["first value", "second value"]);
    expect(coldNative.reads, 1);
    expect(coldNative.writes, 0);
  });

  test("updates and deletes of independent rows cannot lose another row", () async {
    await repository.write(key: first, value: "before");
    await Future.wait([
      repository.write(key: first, value: "after"),
      repository.write(key: second, value: "retained"),
    ]);
    await Future.wait([
      repository.delete(key: first),
      repository.write(key: second, value: "retained update"),
    ]);
    expect(await repository.read(key: first), isNull);
    expect(await repository.read(key: second), "retained update");
    expect(native.reads, 1);
    expect(native.writes, 1);
  });

  test("existing ciphertext without its native key is never overwritten or re-keyed", () async {
    await repository.write(key: first, value: "existing credential");
    final before = await api.readCiphertext(key: first.storageKey);
    final lost = FixtureMasterKeyStore(value: null);
    final restored = DesktopSecureStorageRepository(
      storageApi: DesktopSecureStorageApi(database: database, masterKeyStore: lost),
      cipher: cipher,
    );

    await expectLater(restored.read(key: first), throwsA(isA<DesktopMasterKeyMissingException>()));
    await expectLater(
      restored.write(key: first, value: "replacement"),
      throwsA(isA<DesktopMasterKeyMissingException>()),
    );
    expect(await api.readCiphertext(key: first.storageKey), before);
    expect(lost.reads, 1);
    expect(lost.writes, 0);

    await restored.delete(key: first);
    expect(await api.hasEncryptedValues(), isFalse);
    await expectLater(restored.write(key: second, value: "new"), throwsA(isA<DesktopMasterKeyMissingException>()));
    expect(lost.reads, 1);
  });

  for (final encoded in ["invalid fixture key!", base64Encode(List<int>.filled(16, 1))]) {
    test("invalid native key stays failed for all later secret writes ($encoded)", () async {
      native.storedValue = encoded;
      for (final key in [first, second]) {
        await expectLater(repository.write(key: key, value: "value"), throwsA(isA<DesktopStorageException>()));
      }
      expect(native.reads, 1);
      expect(native.writes, 0);
      expect(await api.hasEncryptedValues(), isFalse);
      expect(native.storedValue, encoded);
    });
  }

  test("denied native reads retain their cause and do not retry or block preferences", () async {
    const marker = "fixture-private-native-payload";
    const cause = FormatException(marker, marker);
    native.readFailure = cause;
    final failure = isA<DesktopStorageException>()
        .having((e) => e.operation, "operation", DesktopStorageOperation.readMasterKey)
        .having((e) => e.innerError, "cause", same(cause))
        .having((e) => e.toString(), "presentation", isNot(contains(marker)));
    await expectLater(repository.write(key: first, value: "secret"), throwsA(failure));
    await expectLater(repository.write(key: second, value: "secret"), throwsA(failure));
    expect(native.reads, 1);
    expect(native.writes, 0);
    expect(await api.hasEncryptedValues(), isFalse);
    await primitive.writeBool(key: "registered", value: true);
    expect(await primitive.readBool(key: "registered"), isTrue);
  });

  test("failed native saves stay failed and cannot leave unrecoverable ciphertext", () async {
    final cause = StateError("fixture native save denied");
    native.writeFailure = cause;
    final failure = isA<DesktopStorageException>()
        .having((e) => e.operation, "operation", DesktopStorageOperation.writeMasterKey)
        .having((e) => e.innerError, "cause", same(cause));
    await expectLater(repository.write(key: first, value: "secret"), throwsA(failure));
    native.writeFailure = null;
    await expectLater(repository.write(key: first, value: "secret"), throwsA(failure));
    expect(native.reads, 1);
    expect(native.writes, 1);
    expect(native.storedValue, isNull);
    expect(await api.hasEncryptedValues(), isFalse);

    final relaunched = DesktopSecureStorageRepository(storageApi: api, cipher: cipher);
    await relaunched.write(key: first, value: "recover after relaunch");
    expect(await relaunched.read(key: first), "recover after relaunch");
    expect(native.reads, 2);
    expect(native.writes, 2);
  });

  test("deleting corrupt secret rows needs neither decryption nor native access", () async {
    await repository.write(key: first, value: "first");
    await repository.write(key: second, value: "second");
    final corrupt = (await api.readCiphertext(key: first.storageKey))!;
    corrupt[0] = 9;
    await api.writeCiphertext(key: first.storageKey, ciphertext: corrupt);
    final denied = FixtureMasterKeyStore(value: null)..readFailure = StateError("fixture denied");
    final cold = DesktopSecureStorageRepository(
      storageApi: DesktopSecureStorageApi(database: database, masterKeyStore: denied),
      cipher: cipher,
    );
    await cold.delete(key: first);
    expect(denied.reads, 0);
    expect(denied.writes, 0);
    expect(await api.readCiphertext(key: first.storageKey), isNull);
    expect(await repository.read(key: second), "second");
    expect(native.storedValue, isNotNull);
  });

  test("wrong native key fails authentication without modifying the stored row", () async {
    await repository.write(key: first, value: "existing credential");
    final before = await api.readCiphertext(key: first.storageKey);
    final wrongNative = FixtureMasterKeyStore(
      value: await cipher.encodeMasterKey(masterKey: await cipher.generateMasterKey()),
    );
    final wrong = DesktopSecureStorageRepository(
      storageApi: DesktopSecureStorageApi(database: database, masterKeyStore: wrongNative),
      cipher: cipher,
    );
    await expectLater(wrong.read(key: first), throwsA(isA<DesktopStorageException>()));
    expect(await api.readCiphertext(key: first.storageKey), before);
    expect(wrongNative.writes, 0);
  });

  test("encryption failure leaves the previously committed value intact", () async {
    await repository.write(key: first, value: "before");
    final failingCipher = _MockCipher();
    final encoded = native.storedValue!;
    final key = cipher.decodeMasterKey(encoded: encoded);
    final cause = StateError("fixture encryption failed");
    when(() => failingCipher.decodeMasterKey(encoded: encoded)).thenReturn(key);
    when(() => failingCipher.encrypt(key: first.storageKey, value: "after", masterKey: key)).thenThrow(cause);
    final failing = DesktopSecureStorageRepository(storageApi: api, cipher: failingCipher);
    await expectLater(failing.write(key: first, value: "after"), throwsA(same(cause)));
    expect(await repository.read(key: first), "before");
  });

  test("failed SQL upserts preserve the previously committed value", () async {
    await repository.write(key: first, value: "before");
    await database.customStatement("""
      CREATE TRIGGER reject_secret_update BEFORE UPDATE ON encrypted_values
      BEGIN SELECT RAISE(ABORT, 'fixture update denied'); END;
    """);
    await expectLater(repository.write(key: first, value: "after"), throwsA(isA<Exception>()));
    expect(await repository.read(key: first), "before");
  });

  test("SQLite rollback discards only the failed transaction's ciphertext changes", () async {
    await repository.write(key: first, value: "before");
    final ciphertext = (await api.readCiphertext(key: first.storageKey))!;
    final failure = StateError("fixture rollback");
    await expectLater(
      database.transaction(() async {
        await api.deleteCiphertext(key: first.storageKey);
        await api.writeCiphertext(key: second.storageKey, ciphertext: ciphertext);
        throw failure;
      }),
      throwsA(same(failure)),
    );
    expect(await repository.read(key: first), "before");
    expect(await repository.read(key: second), isNull);
  });
}

class _MockCipher() extends Mock implements DesktopStorageCipher;
