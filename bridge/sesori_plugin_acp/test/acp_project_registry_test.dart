import "dart:async";
import "dart:convert";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// In-memory [HostJsonStore] so registry persistence is exercised without
/// touching disk. Mirrors the real store's plain-string contract.
class _FakeStore implements HostJsonStore {
  final Map<String, String> files = {};
  final Map<String, String> quarantined = {};

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {
    final value = files.remove(name);
    if (value != null) quarantined[quarantinedName] = value;
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
      return null;
    }
    files[name] = next;
    return next;
  }
}

/// A store whose `write` completions are gated, so a test can hold a write in
/// flight and observe whether a second write is (wrongly) issued concurrently.
class _GatedStore implements HostJsonStore {
  final List<String> writes = [];
  final List<Completer<void>> _gates = [];
  String? current;

  @override
  Future<String?> read({required String name}) async => current;

  @override
  Future<void> write({required String name, required String contents}) {
    writes.add(contents);
    final gate = Completer<void>();
    _gates.add(gate);
    return gate.future.then((_) => current = contents);
  }

  /// Completes the oldest in-flight write.
  void releaseNext() => _gates.removeAt(0).complete();

  @override
  Future<void> delete({required String name}) async => current = null;

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {}

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async =>
      current = await transform(current);
}

void main() {
  group("AcpProjectRegistry", () {
    Future<void> pump() => Future<void>.delayed(Duration.zero);

    // Monotonic clock so createdAt ordering is deterministic per call sequence.
    int Function() monotonic() {
      var t = 1000;
      return () => ++t;
    }

    test("seeds the launch cwd as the only project", () async {
      final reg = AcpProjectRegistry(cwd: "/repo", nowMs: monotonic());
      await reg.ensureLoaded();
      final projects = reg.list();
      expect(projects, hasLength(1));
      expect(projects.single.id, "/repo");
      expect(projects.single.name, "repo");
    });

    test("register adds a project and getProjects includes it, newest first", () async {
      final reg = AcpProjectRegistry(cwd: "/repo", nowMs: monotonic());
      await reg.register("/Users/x/alpha");
      await reg.register("/Users/x/beta");
      final ids = reg.list().map((p) => p.id).toList();
      // Newest registration first, launch cwd (seeded oldest) last.
      expect(ids, ["/Users/x/beta", "/Users/x/alpha", "/repo"]);
      expect(reg.list().firstWhere((p) => p.id == "/Users/x/beta").name, "beta");
    });

    test("normalizes trailing slashes and . segments to one id", () async {
      final reg = AcpProjectRegistry(cwd: "/repo", nowMs: monotonic());
      final a = await reg.register("/Users/x/proj/");
      final b = await reg.register("/Users/x/./proj");
      expect(a, b);
      expect(reg.list().where((p) => p.id == "/Users/x/proj"), hasLength(1));
    });

    test("empty/blank path falls back to cwd, does not create a row", () async {
      final reg = AcpProjectRegistry(cwd: "/repo", nowMs: monotonic());
      final id = await reg.register("   ");
      expect(id, "/repo");
      expect(reg.list(), hasLength(1));
    });

    test("persists opened projects (not the cwd seed) to the store", () async {
      final store = _FakeStore();
      final reg = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await reg.register("/Users/x/alpha");

      final raw = store.files[AcpProjectRegistry.defaultFileName];
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      final persistedIds = (decoded["projects"] as List).map((e) => (e as Map)["id"]).toList();
      expect(persistedIds, ["/Users/x/alpha"], reason: "launch cwd is re-seeded, never written");
    });

    test("a fresh registry instance loads persisted projects", () async {
      final store = _FakeStore();
      final first = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await first.register("/Users/x/alpha");

      // Simulate a bridge restart: a brand-new registry over the same store.
      final second = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await second.ensureLoaded();
      final ids = second.list().map((p) => p.id).toSet();
      expect(ids, {"/repo", "/Users/x/alpha"});
    });

    test("the cwd seed stays oldest across a restart, even with a later clock", () async {
      final store = _FakeStore();
      final first = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await first.register("/Users/x/alpha");

      // Restart much later: a fresh registry whose clock is well ahead of when
      // alpha was opened. The implicit cwd default must not leapfrog alpha to
      // the top just because it is re-seeded at the (later) load time.
      var late = 9000;
      final second = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: () => ++late);
      await second.ensureLoaded();
      expect(second.list().map((p) => p.id).toList(), ["/Users/x/alpha", "/repo"]);
    });

    test("rename sets a custom display name and persists it across reloads", () async {
      final store = _FakeStore();
      final first = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await first.register("/Users/x/alpha");
      await first.rename(path: "/Users/x/alpha", name: "My Alpha");
      expect(first.projectFor("/Users/x/alpha").name, "My Alpha");

      final second = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await second.ensureLoaded();
      expect(second.projectFor("/Users/x/alpha").name, "My Alpha");
    });

    test("corrupt persisted JSON is quarantined and the cwd seed survives", () async {
      final store = _FakeStore()..files[AcpProjectRegistry.defaultFileName] = "{not json";
      final reg = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await reg.ensureLoaded();
      expect(reg.list().map((p) => p.id), ["/repo"]);
      expect(store.quarantined, isNotEmpty);
    });

    test("projectFor returns a synthesized project for an unknown path without registering it", () async {
      final reg = AcpProjectRegistry(cwd: "/repo", nowMs: monotonic());
      await reg.ensureLoaded();
      final project = reg.projectFor("/Users/x/unknown");
      expect(project.id, "/Users/x/unknown");
      expect(project.name, "unknown");
      expect(reg.list().map((p) => p.id), ["/repo"], reason: "projectFor must not register");
    });

    test("concurrent registers serialize writes and lose no entries", () async {
      final store = _GatedStore();
      final reg = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await reg.ensureLoaded();

      final a = reg.register("/Users/x/alpha");
      final b = reg.register("/Users/x/beta");
      await pump();

      // The second write must be queued behind the first, not issued in
      // parallel (which could complete out of order and drop an entry).
      expect(store.writes, hasLength(1), reason: "writes are serialized");

      store.releaseNext();
      await pump();
      expect(store.writes, hasLength(2), reason: "the queued write runs once the first completes");

      store.releaseNext();
      await Future.wait([a, b]);

      final decoded = jsonDecode(store.current!) as Map<String, dynamic>;
      final ids = (decoded["projects"] as List).map((e) => (e as Map)["id"]).toSet();
      expect(ids, {"/Users/x/alpha", "/Users/x/beta"});
    });

    test("re-registering an existing project does not rewrite the store", () async {
      final store = _FakeStore();
      final reg = AcpProjectRegistry(cwd: "/repo", store: store, nowMs: monotonic());
      await reg.register("/Users/x/alpha");
      final firstWrite = store.files[AcpProjectRegistry.defaultFileName];
      await reg.register("/Users/x/alpha");
      expect(store.files[AcpProjectRegistry.defaultFileName], firstWrite);
    });
  });
}
