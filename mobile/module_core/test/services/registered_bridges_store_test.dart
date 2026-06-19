import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/services/registered_bridges_store.dart";
import "package:test/test.dart";

/// In-memory [SecureStorage] that records how often each operation runs (so
/// tests can assert the in-memory cache avoids redundant reads) and can be told
/// to throw, simulating a keychain failure.
class _InMemorySecureStorage implements SecureStorage {
  final Map<String, String> data = {};
  int reads = 0;
  int writes = 0;
  int deletes = 0;
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;

  /// When set, `read` blocks on this until completed — lets a test interleave
  /// an account switch with an in-flight read.
  Completer<void>? readGate;

  @override
  Future<String?> read({required String key}) async {
    reads++;
    if (throwOnRead) throw Exception("read failed");
    if (readGate != null) await readGate!.future;
    return data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes++;
    if (throwOnWrite) throw Exception("write failed");
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deletes++;
    if (throwOnDelete) throw Exception("delete failed");
    data.remove(key);
  }
}

class _MockAuthSession extends Mock implements AuthSession {}

AuthUser _user(String id) => AuthUser(
  id: id,
  provider: AuthProvider.github,
  providerUserId: "pid-$id",
  providerUsername: "user-$id",
);

/// Lets pending microtasks (the store's auth-state listener) settle.
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
    // Default: acct-1 is signed in.
    authState = BehaviorSubject<AuthState>.seeded(AuthState.authenticated(user: _user("acct-1")));
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

  String keyFor(String accountId) => "has_registered_bridges.$accountId";

  test("reports no registered bridges for a fresh account", () async {
    final store = buildStore();
    expect(await store.hasRegisteredBridges(), isFalse);
  });

  test("markRegistered latches in memory and under the account's key", () async {
    final store = buildStore();

    await store.markRegistered();

    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage.data[keyFor("acct-1")], "true");
    expect(storage.writes, 1);
  });

  test("markRegistered is idempotent — a repeat call does not write again", () async {
    final store = buildStore();

    await store.markRegistered();
    await store.markRegistered();

    expect(storage.writes, 1);
    expect(await store.hasRegisteredBridges(), isTrue);
  });

  test("a persisted latch is honoured after a restart (new store instance)", () async {
    await buildStore().markRegistered();

    final restarted = buildStore();
    expect(await restarted.hasRegisteredBridges(), isTrue);
  });

  test("the in-memory cache serves the positive answer without re-reading storage", () async {
    storage.data[keyFor("acct-1")] = "true";
    final store = buildStore();

    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage.reads, 1, reason: "first call reads persistence");

    expect(await store.hasRegisteredBridges(), isTrue);
    expect(storage.reads, 1, reason: "subsequent calls are served from memory");
  });

  test("logout clears the in-memory flag and the account's persisted key", () async {
    final store = buildStore();
    await store.markRegistered();
    expect(await store.hasRegisteredBridges(), isTrue);

    authState.add(const AuthState.unauthenticated());
    await _settle();

    expect(storage.data.containsKey(keyFor("acct-1")), isFalse);
    expect(await store.hasRegisteredBridges(), isFalse, reason: "signed out -> no account");
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

  // ---------------------------------------------------------------------------
  // Per-account isolation — the heart of the review feedback.
  // ---------------------------------------------------------------------------

  test("a different account does not inherit the previous account's latch", () async {
    final store = buildStore();
    await store.markRegistered(); // acct-1 latched
    expect(storage.data[keyFor("acct-1")], "true");

    authState.add(AuthState.authenticated(user: _user("acct-2")));
    await _settle();

    expect(await store.hasRegisteredBridges(), isFalse, reason: "acct-2 reads its own (empty) key");
  });

  test("a failed logout delete cannot leak the latch to a different account", () async {
    final store = buildStore();
    await store.markRegistered(); // acct-1 latched + persisted
    storage.throwOnDelete = true;

    // Logout: the delete throws and is swallowed, so acct-1's key lingers.
    authState.add(const AuthState.unauthenticated());
    await _settle();
    expect(storage.data[keyFor("acct-1")], "true", reason: "delete failed, the key remains");

    // A different account signs in on the same device, same app session.
    authState.add(AuthState.authenticated(user: _user("acct-2")));
    await _settle();

    expect(
      await store.hasRegisteredBridges(),
      isFalse,
      reason: "acct-2 reads has_registered_bridges.acct-2, never acct-1's stale key",
    );
  });

  test("an account switch during an in-flight read does not cache for the new account", () async {
    storage.data[keyFor("acct-1")] = "true";
    final gate = Completer<void>();
    storage.readGate = gate;
    final store = buildStore(); // acct-1 signed in

    // Start the read for acct-1; it suspends on the gate.
    final pending = store.hasRegisteredBridges();

    // acct-2 signs in while acct-1's read is still in flight.
    authState.add(AuthState.authenticated(user: _user("acct-2")));
    await _settle();

    // acct-1's read now completes with "true".
    gate.complete();
    expect(await pending, isFalse, reason: "acct-1's late result must not latch onto acct-2");

    // acct-2's own lookup reads its own (empty) key — not a stale cached flag.
    storage.readGate = null;
    expect(await store.hasRegisteredBridges(), isFalse);
  });

  test("the same account keeps its latch after a failed logout delete and re-login", () async {
    final store = buildStore();
    await store.markRegistered();
    storage.throwOnDelete = true;

    authState.add(const AuthState.unauthenticated());
    await _settle();

    // acct-1 signs back in; its key survived the failed delete, which is
    // correct — acct-1 really does have a registered bridge.
    authState.add(AuthState.authenticated(user: _user("acct-1")));
    await _settle();

    expect(await store.hasRegisteredBridges(), isTrue);
  });

  // ---------------------------------------------------------------------------
  // Storage failure paths.
  // ---------------------------------------------------------------------------

  test("a storage read failure fails soft to false", () async {
    storage.data[keyFor("acct-1")] = "true";
    storage.throwOnRead = true;
    final store = buildStore();

    expect(await store.hasRegisteredBridges(), isFalse);
  });

  test("a storage write failure still latches in memory for this run", () async {
    storage.throwOnWrite = true;
    final store = buildStore();

    await store.markRegistered(); // must not throw
    expect(await store.hasRegisteredBridges(), isTrue, reason: "in-memory latch holds");
    expect(storage.data.containsKey(keyFor("acct-1")), isFalse, reason: "nothing persisted");
  });

  test("a delete failure routed through the logout listener does not throw", () async {
    final store = buildStore();
    await store.markRegistered();
    storage.throwOnDelete = true;

    authState.add(const AuthState.unauthenticated());
    await _settle();

    // No uncaught async error; signed out, so there is no account to report.
    expect(await store.hasRegisteredBridges(), isFalse);
  });
}
