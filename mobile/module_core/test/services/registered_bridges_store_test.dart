import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/services/registered_bridges_store.dart";
import "package:test/test.dart";

/// In-memory [SecureStorage] that also records how often each operation runs,
/// so tests can assert the in-memory cache avoids redundant storage reads.
class _InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _data = {};
  int reads = 0;
  int writes = 0;
  int deletes = 0;

  /// When set, the matching operation throws, simulating a keychain failure.
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;

  @override
  Future<String?> read({required String key}) async {
    reads++;
    if (throwOnRead) throw Exception("read failed");
    return _data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes++;
    if (throwOnWrite) throw Exception("write failed");
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deletes++;
    if (throwOnDelete) throw Exception("delete failed");
    _data.remove(key);
  }
}

class _MockAuthSession extends Mock implements AuthSession {}

/// Lets pending microtasks (the store's unawaited clear-on-logout) settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _InMemorySecureStorage storage;
  late BehaviorSubject<AuthState> authState;
  late _MockAuthSession authSession;

  setUp(() {
    storage = _InMemorySecureStorage();
    authState = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
    authSession = _MockAuthSession();
    when(() => authSession.authStateStream).thenAnswer((_) => authState);
  });

  tearDown(() async {
    await authState.close();
  });

  RegisteredBridgesStore buildStore() => RegisteredBridgesStore(
    secureStorage: storage,
    authSession: authSession,
  );

  test("reports no registered bridges for a fresh account", () async {
    final store = buildStore();
    expect(await store.hasRegisteredBridges(), isFalse);
  });

  test("markRegistered latches the answer in memory and in storage", () async {
    final store = buildStore();

    await store.markRegistered();

    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage.writes, 1);
  });

  test("markRegistered is idempotent — a repeat call does not write again", () async {
    final store = buildStore();

    await store.markRegistered();
    await store.markRegistered();

    expect(storage.writes, 1);
  });

  test("a persisted latch is honoured after a restart (new store instance)", () async {
    // First run: latch the positive answer.
    await buildStore().markRegistered();

    // Simulate an app restart: a brand-new store reading the same storage.
    final restarted = buildStore();
    expect(await restarted.hasRegisteredBridges(), isTrue);
  });

  test("the in-memory cache serves the positive answer without re-reading storage", () async {
    storage._data["has_registered_bridges"] = "true";
    final store = buildStore();

    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage.reads, 1, reason: "first call reads persistence");

    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage.reads, 1, reason: "subsequent calls are served from memory");
  });

  test("logout clears both the in-memory flag and the persisted latch", () async {
    final store = buildStore();
    await store.markRegistered();
    expect(await store.hasRegisteredBridges(), isTrue);

    authState.add(const AuthState.unauthenticated());
    await _settle();

    expect(storage._data.containsKey("has_registered_bridges"), isFalse);
    expect(storage.deletes, greaterThanOrEqualTo(1));
    expect(await store.hasRegisteredBridges(), isFalse);
  });

  test("non-logout auth states leave the latch untouched", () async {
    final store = buildStore();
    await store.markRegistered();

    authState
      ..add(const AuthState.authenticating())
      ..add(const AuthState.failed(error: "boom"));
    await _settle();

    expect(storage.deletes, 0);
    expect(await store.hasRegisteredBridges(), isTrue);
  });

  test("a storage read failure fails soft to false", () async {
    storage._data["has_registered_bridges"] = "true";
    storage.throwOnRead = true;
    final store = buildStore();

    expect(await store.hasRegisteredBridges(), isFalse);
  });

  test("a storage write failure still latches in memory for this run", () async {
    storage.throwOnWrite = true;
    final store = buildStore();

    await store.markRegistered(); // must not throw
    expect(await store.hasRegisteredBridges(), isTrue, reason: "in-memory latch holds");
    expect(storage._data.containsKey("has_registered_bridges"), isFalse, reason: "nothing persisted");
  });

  test("a storage delete failure on logout is swallowed and leaves the flags consistent", () async {
    final store = buildStore();
    await store.markRegistered();
    storage.throwOnDelete = true;

    // Direct call must not throw…
    await store.clear();
    // …and, since the delete failed, the in-memory flag is not cleared ahead of
    // storage — both still report the (un-deleted) positive latch.
    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage._data["has_registered_bridges"], "true");
  });

  test("a delete failure routed through the logout listener does not throw", () async {
    final store = buildStore();
    await store.markRegistered();
    storage.throwOnDelete = true;

    // The listener calls clear() fire-and-forget; a throwing delete must be
    // caught inside clear() rather than surfacing as an uncaught async error.
    authState.add(const AuthState.unauthenticated());
    await _settle();

    expect(await store.hasRegisteredBridges(), isTrue);
  });

  test("a new account can latch again after a logout cleared the previous one", () async {
    final store = buildStore();
    await store.markRegistered();
    authState.add(const AuthState.unauthenticated());
    await _settle();
    expect(await store.hasRegisteredBridges(), isFalse);

    await store.markRegistered();
    expect(await store.hasRegisteredBridges(), isTrue);
  });
}
