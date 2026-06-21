import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/runtime/open_code_managed_api.dart";
import "package:opencode_plugin/src/runtime/open_code_ownership_record.dart";
import "package:opencode_plugin/src/runtime/open_code_plugin_descriptor.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodePluginDescriptor static surface", () {
    const descriptor = OpenCodePluginDescriptor();

    test("declares the OpenCode CLI options with bare names", () {
      expect(descriptor.id, equals("opencode"));
      expect(descriptor.displayName, equals("OpenCode"));
      expect(
        descriptor.options.map((o) => o.name).toList(),
        equals(<String>["port", "host", "no-auto-start", "password", "no-password", "bin"]),
      );
    });

    test("keeps the pre-namespacing flags as deprecated aliases", () {
      final aliasesByName = <String, List<String>>{
        for (final option in descriptor.options) option.name: option.deprecatedAliases,
      };
      expect(aliasesByName["port"], equals(<String>["port"]));
      expect(aliasesByName["no-auto-start"], equals(<String>["no-auto-start"]));
      expect(aliasesByName["password"], equals(<String>["password"]));
      // host is new and bin already namespaced to --opencode-bin: no aliases.
      expect(aliasesByName["host"], isEmpty);
      expect(aliasesByName["bin"], isEmpty);
    });

    test("validateConfig requires --port when --no-auto-start is set", () {
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": null, "host": "127.0.0.1", "password": "", "bin": "opencode", "no-password": false}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": "4096", "host": "127.0.0.1", "password": "", "bin": "opencode", "no-password": false}),
        ),
        returnsNormally,
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "127.0.0.1", "password": "", "bin": "opencode", "no-password": false}),
        ),
        returnsNormally,
      );
    });

    test("validateConfig rejects --no-password together with --password", () {
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": "4096", "host": "127.0.0.1", "password": "secret", "bin": "opencode", "no-password": true}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": "4096", "host": "127.0.0.1", "password": "", "bin": "opencode", "no-password": true}),
        ),
        returnsNormally,
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": "4096", "host": "127.0.0.1", "password": "secret", "bin": "opencode", "no-password": false}),
        ),
        returnsNormally,
      );
    });

    test("validateConfig rejects an empty or whitespace-only host", () {
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "", "password": "", "bin": "opencode", "no-password": false}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "   ", "password": "", "bin": "opencode", "no-password": false}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
    });

    test("validateConfig rejects a host that carries a scheme or path", () {
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "http://127.0.0.1", "password": "", "bin": "opencode", "no-password": false}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
    });

    test("validateConfig rejects --no-password with a non-loopback managed bind", () {
      // 0.0.0.0 + auth disabled would expose an unauthenticated server.
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "0.0.0.0", "password": "", "bin": "opencode", "no-password": true}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
      // Loopback + no-password is fine (not network-exposed).
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "127.0.0.1", "password": "", "bin": "opencode", "no-password": true}),
        ),
        returnsNormally,
      );
      // 0.0.0.0 with auth (no --no-password) stays allowed — the Docker case.
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "0.0.0.0", "password": "", "bin": "opencode", "no-password": false}),
        ),
        returnsNormally,
      );
      // Attach mode does not bind, so a non-loopback host + no-password is fine.
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": "4096", "host": "10.0.0.5", "password": "", "bin": "opencode", "no-password": true}),
        ),
        returnsNormally,
      );
      // A DNS name that merely starts with "127." is NOT loopback and must not
      // bypass the guard.
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "127.evil.com", "password": "", "bin": "opencode", "no-password": true}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
      // A non-127.0.0.1 address in the loopback range is still loopback.
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "host": "127.0.0.2", "password": "", "bin": "opencode", "no-password": true}),
        ),
        returnsNormally,
      );
    });
  });

  group("OpenCodePluginDescriptor.start (managed)", () {
    late _FakeHost host;
    late _FakeApiRecorder apiRecorder;
    late List<Map<String, String>> optimizeCalls;

    setUp(() {
      host = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "127.0.0.1",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": false,
          },
        ),
      );
      apiRecorder = _FakeApiRecorder();
      optimizeCalls = <Map<String, String>>[];
    });

    OpenCodePluginDescriptor descriptor({Object? initializeError}) {
      apiRecorder.initializeError = initializeError;
      return OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
        candidatePorts: const <int>[51000],
        random: Random(1),
        optimizeDb: ({required Map<String, String> environment}) async {
          optimizeCalls.add(environment);
        },
      );
    }

    test("spawns, owns, becomes Ready, and persists a ready record", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(plugin.port, equals(51000));
      expect(plugin.serverUrl, equals("http://127.0.0.1:51000"));
      expect(plugin.describe().details["mode"], equals("managed"));
      expect(plugin.describe().endpoint, equals("http://127.0.0.1:51000"));
      expect(apiRecorder.last!.initializeCalled, isTrue);
      expect(apiRecorder.last!.onConnected, isNotNull);

      final record = host.ownershipRecord("owner-current");
      expect(record, isNotNull);
      expect(record!["status"], equals("ready"));
      expect(record["port"], equals(51000));
      expect(record["openCodePid"], equals(4242));

      await plugin.shutdown(budget: null);
    });

    test("binding 0.0.0.0 records the wildcard but connects over loopback", () async {
      final wildcardHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "0.0.0.0",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": false,
          },
        ),
      );
      wildcardHost.ports.defaultBindable = true;

      final plugin = await descriptor().start(wildcardHost);

      // 0.0.0.0 is not a connectable target, so the bridge dials loopback.
      expect(plugin.serverUrl, equals("http://127.0.0.1:51000"));
      // ...while OpenCode is actually told to bind the wildcard.
      final record = wildcardHost.ownershipRecord("owner-current");
      expect(
        record!["openCodeArgs"],
        equals(<String>["serve", "--port", "51000", "--hostname", "0.0.0.0"]),
      );

      await plugin.shutdown(budget: null);
    });

    test("binding a concrete host connects to that host verbatim", () async {
      final concreteHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "10.0.0.5",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": false,
          },
        ),
      );
      concreteHost.ports.defaultBindable = true;

      final plugin = await descriptor().start(concreteHost);

      expect(plugin.serverUrl, equals("http://10.0.0.5:51000"));

      await plugin.shutdown(budget: null);
    });

    test("binding the IPv6 wildcard connects over IPv6 loopback", () async {
      final wildcardHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "::",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": false,
          },
        ),
      );
      wildcardHost.ports.defaultBindable = true;

      final plugin = await descriptor().start(wildcardHost);

      // :: resolves to ::1 (same address family), bracketed in the URL.
      expect(plugin.serverUrl, equals("http://[::1]:51000"));
      final record = wildcardHost.ownershipRecord("owner-current");
      expect(
        record!["openCodeArgs"],
        equals(<String>["serve", "--port", "51000", "--hostname", "::"]),
      );

      await plugin.shutdown(budget: null);
    });

    test("brackets an IPv6 literal host in the server URL", () async {
      final ipv6Host = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "::1",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": false,
          },
        ),
      );
      ipv6Host.ports.defaultBindable = true;

      final plugin = await descriptor().start(ipv6Host);

      expect(plugin.serverUrl, equals("http://[::1]:51000"));

      await plugin.shutdown(budget: null);
    });

    test("trims surrounding whitespace on the configured host", () async {
      final paddedHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "  0.0.0.0  ",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": false,
          },
        ),
      );
      paddedHost.ports.defaultBindable = true;

      final plugin = await descriptor().start(paddedHost);

      // Trimmed to the wildcard, which resolves to the loopback connect host.
      expect(plugin.serverUrl, equals("http://127.0.0.1:51000"));
      final record = paddedHost.ownershipRecord("owner-current");
      expect(
        record!["openCodeArgs"],
        equals(<String>["serve", "--port", "51000", "--hostname", "0.0.0.0"]),
      );

      await plugin.shutdown(budget: null);
    });

    test("--no-password spawns without OPENCODE_SERVER_PASSWORD", () async {
      host = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": null,
            "host": "127.0.0.1",
            "no-auto-start": false,
            "password": "",
            "bin": "/bin/opencode",
            "no-password": true,
          },
        ),
      );
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(apiRecorder.last!.password, isNull);
      expect(host.processes.spawnedProcesses, hasLength(1));
      final environment = host.processes.spawnEnvironments.single;
      expect(environment, isNotNull);
      expect(environment!.containsKey("OPENCODE_SERVER_PASSWORD"), isFalse);

      await plugin.shutdown(budget: null);
    });

    test("maps a cold-start failure to Degraded without failing the bridge", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor(initializeError: StateError("cold start failed")).start(host);

      expect(plugin.currentStatus, isA<PluginDegraded>());
      // The runtime is still owned and recorded — only the api cold-start failed.
      expect(host.ownershipRecord("owner-current"), isNotNull);

      await plugin.shutdown(budget: null);
    });

    test("an unexpected child exit restarts on the pinned port and recovers", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);
      expect(plugin.currentStatus, isA<PluginReady>());

      host.processes.spawnedProcesses.single.completeExit(1);
      await pumpEventQueue();

      expect(host.processes.spawnedProcesses, hasLength(2), reason: "the monitor must respawn the child");
      expect(plugin.currentStatus, isA<PluginReady>());
      final record = host.ownershipRecord("owner-current");
      expect(record!["port"], equals(51000), reason: "restart is pinned to the original port");
      expect(record["status"], equals("ready"));

      await plugin.shutdown(budget: null);
    });

    test("an unexpected exit surfaces as Failed when the pinned port never frees", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);
      expect(plugin.currentStatus, isA<PluginReady>());

      host.ports.byPort[51000] = false;
      host.processes.spawnedProcesses.single.completeExit(1);
      await pumpEventQueue();

      expect(plugin.currentStatus, isA<PluginFailed>());
      expect(host.processes.spawnedProcesses, hasLength(1), reason: "no child can spawn while the port is held");
    });

    test("runs the DB maintenance seam with the host environment before starting", () async {
      host.ports.defaultBindable = true;

      final plugin = await descriptor().start(host);

      expect(optimizeCalls, hasLength(1));
      expect(optimizeCalls.single, same(host.environment));

      await plugin.shutdown(budget: null);
    });

    test("a throwing DB maintenance seam never fails the start", () async {
      host.ports.defaultBindable = true;
      final throwingDescriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
        candidatePorts: const <int>[51000],
        random: Random(1),
        optimizeDb: ({required Map<String, String> environment}) async {
          throw StateError("maintenance exploded");
        },
      );

      final plugin = await throwingDescriptor.start(host);

      expect(plugin.currentStatus, isA<PluginReady>());

      await plugin.shutdown(budget: null);
    });

    test("records the start intent before spawn and clears it once the record exists", () async {
      host.ports.defaultBindable = true;
      String? intentDuringSpawn;
      host.processes.onSpawn = () {
        intentDuringSpawn = host.store.files["opencode-start-intent.json"];
      };

      final plugin = await descriptor().start(host);

      expect(intentDuringSpawn, isNotNull, reason: "the intent side file must exist before the child does");
      expect(jsonDecode(intentDuringSpawn!), containsPair("port", 51000));
      expect(
        host.store.files["opencode-start-intent.json"],
        isNull,
        reason: "the intent is resolved once the ownership record is written",
      );

      await plugin.shutdown(budget: null);
    });

    test("stale cleanup reclaims a runtime owned by a replaced bridge that still looks live", () async {
      host.ports.defaultBindable = true;
      _seedStaleRecord(host);
      // The replaced bridge's pid still classifies as a live bridge (pid reuse,
      // or the Windows no-start-marker path) — only the terminated-bridge
      // identities from the host authorize reclaiming its runtime.
      host.bridge.liveBridgePids.add(200);
      host.bridge.terminatedBridgeIdentitiesValue = <ProcessIdentity>[
        ProcessIdentity(
          pid: 200,
          startMarker: "old-bridge-start",
          executablePath: "/bin/sesori-bridge",
          commandLine: "sesori-bridge",
          ownerUser: null,
          platform: "macos",
          capturedAt: DateTime.utc(2026, 6, 1),
        ),
      ];

      final plugin = await descriptor().start(host);

      expect(host.processes.signals, contains("graceful:7777"));
      expect(host.ownershipRecord("owner-old"), isNull, reason: "the reclaimed record is deleted");
      expect(host.ownershipRecord("owner-current"), isNotNull);

      await plugin.shutdown(budget: null);
    });

    test("stale cleanup spares a live other-owner bridge when it was not replaced", () async {
      host.ports.defaultBindable = true;
      _seedStaleRecord(host);
      host.bridge.liveBridgePids.add(200);

      final plugin = await descriptor().start(host);

      expect(host.processes.signals, isNot(contains("graceful:7777")));
      expect(host.ownershipRecord("owner-old"), isNotNull, reason: "a live owner's runtime must be spared");

      await plugin.shutdown(budget: null);
    });

    test("shutdown disposes the api, stops the owned runtime, and is idempotent", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);

      await plugin.shutdown(budget: null);
      await plugin.shutdown(budget: null);

      expect(apiRecorder.last!.disposeCount, equals(1));
      expect(plugin.currentStatus, isA<PluginStopped>());
      // The owned runtime was stopped: its ownership record is gone.
      expect(host.ownershipRecord("owner-current"), isNull);
    });

    test("a child exit after shutdown does not flip the status to Failed", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);
      final child = host.processes.spawnedProcesses.single;

      await plugin.shutdown(budget: null);
      child.completeExit(1);
      await pumpEventQueue();

      expect(plugin.currentStatus, isA<PluginStopped>());
    });

    test("an aborted start throws PluginStartAbortedException and leaves no record", () async {
      host.ports.defaultBindable = true;
      host.abort.abort();

      await expectLater(descriptor().start(host), throwsA(isA<PluginStartAbortedException>()));
      expect(host.ownershipRecord("owner-current"), isNull);
    });

    test("an abort raised during cold-start rolls back the owned runtime and throws", () async {
      host.ports.defaultBindable = true;
      apiRecorder.onInitialize = host.abort.abort;

      await expectLater(descriptor().start(host), throwsA(isA<PluginStartAbortedException>()));

      // The api (and its SSE transport) was torn down and the owned child was
      // stopped: its ownership record is gone.
      expect(apiRecorder.last!.disposeCount, equals(1));
      expect(host.ownershipRecord("owner-current"), isNull);
    });
  });

  group("OpenCodePluginDescriptor.start (attach / --no-auto-start)", () {
    late _FakeApiRecorder apiRecorder;

    setUp(() {
      apiRecorder = _FakeApiRecorder();
    });

    _FakeHost attachHost() => _FakeHost(
      config: const PluginConfig(
        values: {
          "port": "4096",
          "host": "127.0.0.1",
          "no-auto-start": true,
          "password": "",
          "bin": "opencode",
          "no-password": false,
        },
      ),
    );

    test("attaches to a reachable server as Ready without owning it", () async {
      final host = attachHost();
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
      );

      final plugin = await descriptor.start(host);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(plugin.port, equals(4096));
      expect(plugin.describe().details["mode"], equals("attached"));
      expect(host.ownershipRecord("owner-current"), isNull);
      expect(host.processes.spawnedProcesses, isEmpty);

      await plugin.shutdown(budget: null);
    });

    test("attaches to a non-loopback host at the configured address", () async {
      final remoteHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": "4096",
            "host": "10.0.0.5",
            "no-auto-start": true,
            "password": "",
            "bin": "opencode",
            "no-password": false,
          },
        ),
      );
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
      );

      final plugin = await descriptor.start(remoteHost);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(plugin.serverUrl, equals("http://10.0.0.5:4096"));

      await plugin.shutdown(budget: null);
    });

    test("--no-password attaches with a null password", () async {
      final host = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": "4096",
            "host": "127.0.0.1",
            "no-auto-start": true,
            "password": "",
            "bin": "opencode",
            "no-password": true,
          },
        ),
      );
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
      );

      final plugin = await descriptor.start(host);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(apiRecorder.last!.password, isNull);

      await plugin.shutdown(budget: null);
    });

    test("starts degraded but does not throw when the existing server is unreachable", () async {
      final host = attachHost();
      apiRecorder.initializeError = const SocketException("connection refused");
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("nope", 503)),
      );

      final plugin = await descriptor.start(host);

      expect(plugin.currentStatus, isA<PluginDegraded>());
      expect(plugin.describe().details["mode"], equals("attached"));
      expect(host.ownershipRecord("owner-current"), isNull);

      await plugin.shutdown(budget: null);
    });

    test("normalizes the password option like the legacy flow (trim, blank to null)", () async {
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
      );

      final trimmedHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": "4096",
            "host": "127.0.0.1",
            "no-auto-start": true,
            "password": "  secret  ",
            "bin": "opencode",
            "no-password": false,
          },
        ),
      );
      final trimmedPlugin = await descriptor.start(trimmedHost);
      expect(apiRecorder.last!.password, equals("secret"));
      await trimmedPlugin.shutdown(budget: null);

      final blankHost = _FakeHost(
        config: const PluginConfig(
          values: {
            "port": "4096",
            "host": "127.0.0.1",
            "no-auto-start": true,
            "password": "   ",
            "bin": "opencode",
            "no-password": false,
          },
        ),
      );
      final blankPlugin = await descriptor.start(blankHost);
      expect(apiRecorder.last!.password, isNull);
      await blankPlugin.shutdown(budget: null);
    });

    test("a stalled cold-start after a healthy attach probe degrades within the budget instead of hanging", () async {
      final host = attachHost();
      // A wrong/wedged service that answers /global/health with 200 but stalls
      // a REST call inside the cold-start: the await must be bounded, or
      // start() hangs under the bridge's cross-instance startup mutex.
      apiRecorder.neverCompleteInitialize = true;
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
        coldStartBudget: const Duration(milliseconds: 200),
      );

      final plugin = await descriptor.start(host).timeout(const Duration(seconds: 5));

      expect(plugin.currentStatus, isA<PluginDegraded>());
      expect(plugin.describe().details["mode"], equals("attached"));

      await plugin.shutdown(budget: null);
    });

    test("a failed attach probe does not block start on the cold-start", () async {
      final host = attachHost();
      // A pathological "server" that accepts connections but never answers: the
      // cold-start future never completes. start() must not await it once the
      // probe has already failed.
      apiRecorder.neverCompleteInitialize = true;
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        optimizeDb: _noopOptimizeDb,
        probeClientFactory: () => MockClient((_) async => http.Response("nope", 503)),
      );

      final plugin = await descriptor.start(host).timeout(const Duration(seconds: 5));

      expect(plugin.currentStatus, isA<PluginDegraded>());
      expect(apiRecorder.last!.initializeCalled, isTrue);

      await plugin.shutdown(budget: null);
    });
  });
}

Future<void> _noopOptimizeDb({required Map<String, String> environment}) async {}

/// Seeds the ownership file with a ready record owned by a *previous* bridge
/// (pid 200) whose `opencode serve` child (pid 7777) is still running and
/// matches the record identity.
void _seedStaleRecord(_FakeHost host) {
  final record = OpenCodeOwnershipRecord(
    ownerSessionId: "owner-old",
    openCodePid: 7777,
    openCodeStartMarker: "old-run",
    openCodeExecutablePath: "/bin/opencode",
    openCodeCommand: "/bin/opencode",
    openCodeArgs: const <String>["serve", "--port", "50999", "--hostname", "127.0.0.1"],
    port: 50999,
    bridgePid: 200,
    bridgeStartMarker: "old-bridge-start",
    startedAt: DateTime.utc(2026, 5, 1),
    status: OpenCodeOwnershipStatus.ready,
  );
  host.store.files["opencode-processes.json"] = jsonEncode(<String, dynamic>{"owner-old": record.toJson()});
  host.processes.inspectResults[7777] = ProcessIdentity(
    pid: 7777,
    startMarker: "old-run",
    executablePath: "/bin/opencode",
    commandLine: "/bin/opencode serve --port 50999 --hostname 127.0.0.1",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeApiRecorder {
  Object? initializeError;
  void Function()? onInitialize;
  bool neverCompleteInitialize = false;
  final List<_FakeManagedApi> built = <_FakeManagedApi>[];

  _FakeManagedApi? get last => built.isEmpty ? null : built.last;

  OpenCodeManagedApi build({
    required String serverUrl,
    required String? password,
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) {
    final api = _FakeManagedApi(
      initializeError: initializeError,
      onInitialize: onInitialize,
      neverCompleteInitialize: neverCompleteInitialize,
      password: password,
      onConnected: onConnected,
      onDisconnected: onDisconnected,
    );
    built.add(api);
    return api;
  }
}

class _FakeManagedApi implements OpenCodeManagedApi {
  _FakeManagedApi({
    required this.initializeError,
    required this.onInitialize,
    required this.neverCompleteInitialize,
    required this.password,
    required this.onConnected,
    required this.onDisconnected,
  });

  final Object? initializeError;
  final void Function()? onInitialize;
  final bool neverCompleteInitialize;
  final String? password;
  final void Function() onConnected;
  final void Function() onDisconnected;
  bool initializeCalled = false;
  int disposeCount = 0;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    onInitialize?.call();
    if (neverCompleteInitialize) {
      return Completer<void>().future;
    }
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }

  @override
  String get id => "opencode";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements PluginHost {
  _FakeHost({required this.config});

  @override
  final PluginConfig config;

  @override
  final String stateDirectory = "/runtime";

  @override
  final Map<String, String> environment = const <String, String>{"PATH": "/usr/bin"};

  @override
  final ServerClock clock = const _ImmediateClock();

  final StartAbortController abort = StartAbortController();

  @override
  StartAbortSignal get startAborted => abort.signal;

  @override
  final _FakeBridgeHostInfo bridge = _FakeBridgeHostInfo();

  @override
  final _FakeHostProcessService processes = _FakeHostProcessService();

  @override
  final _FakePortService ports = _FakePortService();

  @override
  final _MemoryJsonStore store = _MemoryJsonStore();

  Map<String, dynamic>? ownershipRecord(String ownerSessionId) {
    final contents = store.files["opencode-processes.json"];
    if (contents == null) {
      return null;
    }
    final root = jsonDecode(contents) as Map<String, dynamic>;
    final record = root[ownerSessionId];
    return record == null ? null : Map<String, dynamic>.from(record as Map);
  }
}

class _ImmediateClock implements ServerClock {
  const _ImmediateClock();

  @override
  DateTime now() => DateTime.utc(2026, 6, 1, 12);

  @override
  Future<void> delay({required Duration duration}) async {}
}

class _FakeBridgeHostInfo implements BridgeHostInfo {
  List<ProcessIdentity> terminatedBridgeIdentitiesValue = <ProcessIdentity>[];
  final Set<int> liveBridgePids = <int>{};

  @override
  ProcessIdentity get identity => ProcessIdentity(
    pid: 900,
    startMarker: "bridge-marker",
    executablePath: "/bin/sesori-bridge",
    commandLine: "sesori-bridge",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );

  @override
  String get ownerSessionId => "owner-current";

  @override
  List<ProcessIdentity> get terminatedBridgeIdentities => terminatedBridgeIdentitiesValue;

  @override
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker}) async =>
      liveBridgePids.contains(pid);
}

class _FakePortService implements HostPortService {
  bool defaultBindable = true;
  final Map<int, bool> byPort = <int, bool>{};

  @override
  Future<bool> isBindable({required String host, required int port}) async => byPort[port] ?? defaultBindable;
}

class _FakeHostProcessService implements HostProcessService {
  final List<_FakeSpawnedProcess> spawnedProcesses = <_FakeSpawnedProcess>[];
  final List<Map<String, String>?> spawnEnvironments = <Map<String, String>?>[];
  final List<String> signals = <String>[];
  final Map<int, ProcessIdentity> inspectResults = <int, ProcessIdentity>{};
  void Function()? onSpawn;
  int nextPid = 4242;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    onSpawn?.call();
    spawnEnvironments.add(environment);
    final process = _FakeSpawnedProcess(pid: nextPid++, executablePath: executable);
    spawnedProcesses.add(process);
    return process;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => inspectResults[pid];

  @override
  Future<List<ProcessIdentity>> list({required int? excludePid}) async => const <ProcessIdentity>[];

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    signals.add("graceful:$pid");
    inspectResults.remove(pid);
    for (final process in spawnedProcesses) {
      if (process.pid == pid) {
        process.completeExit(0);
      }
    }
    return _signal(pid: pid, signal: ShutdownSignal.graceful);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    signals.add("force:$pid");
    inspectResults.remove(pid);
    return _signal(pid: pid, signal: ShutdownSignal.force);
  }

  SignalResult _signal({required int pid, required ShutdownSignal signal}) {
    return SignalResult(
      pid: pid,
      requestedSignal: signal,
      deliveredSignal: signal == ShutdownSignal.graceful ? ProcessSignal.sigterm : ProcessSignal.sigkill,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 6, 1),
    );
  }
}

class _FakeSpawnedProcess implements SpawnedProcess {
  _FakeSpawnedProcess({required this.pid, required String executablePath}) : _executablePath = executablePath;

  @override
  final int pid;

  final String _executablePath;
  final Completer<int> _exit = Completer<int>();

  void completeExit([int code = 0]) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  ProcessIdentity get identity => ProcessIdentity(
    pid: pid,
    startMarker: null,
    executablePath: _executablePath,
    commandLine: "$_executablePath serve",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(const <int>[]);

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.value(const <int>[]);
}

class _MemoryJsonStore implements HostJsonStore {
  final Map<String, String> files = <String, String>{};

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
    final contents = files.remove(name);
    if (contents != null) {
      files[quarantinedName] = contents;
    }
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
    } else {
      files[name] = next;
    }
    return next;
  }
}
