import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/runtime/open_code_ownership_record.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_policy.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("generateOpenCodePassword", () {
    test("produces 64 lowercase hex characters (32 bytes)", () {
      final password = generateOpenCodePassword(random: Random(1));
      expect(password.length, equals(openCodePasswordLength * 2));
      expect(RegExp(r"^[0-9a-f]+$").hasMatch(password), isTrue);
    });

    test("is deterministic for a seeded source and differs across seeds", () {
      expect(generateOpenCodePassword(random: Random(1)), equals(generateOpenCodePassword(random: Random(1))));
      expect(generateOpenCodePassword(random: Random(1)), isNot(equals(generateOpenCodePassword(random: Random(2)))));
    });
  });

  group("openCodeDynamicCandidates", () {
    test("draws maxAttempts distinct in-range ports excluding the reserved port", () {
      final ports = openCodeDynamicCandidates(random: Random(7)).toList();
      expect(ports, hasLength(dynamicOpenCodeMaxAttempts));
      expect(ports.toSet(), hasLength(dynamicOpenCodeMaxAttempts));
      for (final port in ports) {
        expect(port, inInclusiveRange(dynamicOpenCodePortMin, dynamicOpenCodePortMax));
        expect(port, isNot(equals(openCodeDefaultPort)));
      }
    });

    test("filters supplied candidates by the reserved/in-range rule, preserving order", () {
      final ports = openCodeDynamicCandidates(
        candidates: <int>[openCodeDefaultPort, 49152, 80, 49153, 70000],
      ).toList();
      expect(ports, equals(<int>[49152, 49153]));
    });

    test("bounds a lazy all-invalid supplied source instead of spinning forever", () {
      Iterable<int> infiniteInvalid() sync* {
        while (true) {
          yield openCodeDefaultPort; // reserved → always filtered out
        }
      }

      // Would hang (and fail via the test timeout) if the supplied path were not
      // capped at dynamicOpenCodeMaxAttempts.
      final ports = openCodeDynamicCandidates(candidates: infiniteInvalid()).toList();
      expect(ports, isEmpty);
    });

    test("caps the supplied candidates examined at dynamicOpenCodeMaxAttempts", () {
      final ports = openCodeDynamicCandidates(
        candidates: <int>[49152, 49153, 49154, 49155, 49156, 49157, 49158],
      ).toList();
      expect(ports, hasLength(dynamicOpenCodeMaxAttempts));
      expect(ports, equals(<int>[49152, 49153, 49154, 49155, 49156]));
    });
  });

  group("buildOpenCodeOwnershipRecord", () {
    test("maps the draft into a starting record with the frozen spawn args", () {
      final record = buildOpenCodeOwnershipRecord(
        RuntimeRecordDraft(
          ownerSessionId: "owner-1",
          runtimeIdentity: _identity(pid: 4242, executablePath: "/bin/opencode", startMarker: "marker"),
          port: 51000,
          bridgeIdentity: _identity(pid: 900, executablePath: "/bin/bridge", startMarker: "bridge-marker"),
          startedAt: DateTime.utc(2026, 6, 1, 9, 30),
        ),
      );

      expect(record.ownerSessionId, equals("owner-1"));
      expect(record.openCodePid, equals(4242));
      expect(record.openCodeStartMarker, equals("marker"));
      expect(record.openCodeExecutablePath, equals("/bin/opencode"));
      expect(record.openCodeCommand, equals("/bin/opencode"));
      expect(record.openCodeArgs, equals(<String>["serve", "--port", "51000", "--hostname", "127.0.0.1"]));
      expect(record.port, equals(51000));
      expect(record.bridgePid, equals(900));
      expect(record.bridgeStartMarker, equals("bridge-marker"));
      expect(record.startedAt, equals(DateTime.utc(2026, 6, 1, 9, 30)));
      expect(record.status, equals(OpenCodeOwnershipStatus.starting));
    });

    test("falls back to opencode when the runtime executable path is unknown", () {
      final record = buildOpenCodeOwnershipRecord(
        RuntimeRecordDraft(
          ownerSessionId: "owner-2",
          runtimeIdentity: _identity(pid: 7, executablePath: null, startMarker: null),
          port: 4096,
          bridgeIdentity: _identity(pid: 900, executablePath: "/bin/bridge", startMarker: null),
          startedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      expect(record.openCodeExecutablePath, equals(""));
      expect(record.openCodeCommand, equals("opencode"));
    });
  });

  group("probeOpenCodeHealth", () {
    test("reports healthy on HTTP 200 with Basic auth against /global/health", () async {
      late http.BaseRequest captured;
      final probe = await probeOpenCodeHealth(
        port: 51000,
        password: "secret",
        clientFactory: () => MockClient((request) async {
          captured = request;
          return http.Response("", 200);
        }),
      );

      expect(probe.healthy, isTrue);
      expect(probe.error, isNull);
      expect(captured.url.toString(), equals("http://127.0.0.1:51000/global/health"));
      expect(
        captured.headers["Authorization"],
        equals("Basic ${base64Encode(utf8.encode("opencode:secret"))}"),
      );
    });

    test("omits the Authorization header when password is null", () async {
      late http.BaseRequest captured;
      final probe = await probeOpenCodeHealth(
        port: 51000,
        password: null,
        clientFactory: () => MockClient((request) async {
          captured = request;
          return http.Response("", 200);
        }),
      );

      expect(probe.healthy, isTrue);
      expect(captured.headers.containsKey("Authorization"), isFalse);
    });

    test("omits the Authorization header when password is empty", () async {
      late http.BaseRequest captured;
      final probe = await probeOpenCodeHealth(
        port: 51000,
        password: "",
        clientFactory: () => MockClient((request) async {
          captured = request;
          return http.Response("", 200);
        }),
      );

      expect(probe.healthy, isTrue);
      expect(captured.headers.containsKey("Authorization"), isFalse);
    });

    test("reports unhealthy with an error on a non-200 status", () async {
      final probe = await probeOpenCodeHealth(
        port: 51000,
        password: "secret",
        clientFactory: () => MockClient((request) async => http.Response("nope", 503)),
      );
      expect(probe.healthy, isFalse);
      expect(probe.error, isNotNull);
    });

    test("reports unhealthy when the request throws", () async {
      final probe = await probeOpenCodeHealth(
        port: 51000,
        password: "secret",
        clientFactory: () => MockClient((request) async => throw const SocketException("refused")),
      );
      expect(probe.healthy, isFalse);
      expect(probe.error, isA<SocketException>());
    });

    test("reports unhealthy when the response body never completes within the timeout", () async {
      // A wrong localhost service that sends 200 headers but keeps the body
      // open: the drain must be bounded by the same timeout as the send, or
      // the probe hangs the supervisor under the startup mutex.
      final probe = await probeOpenCodeHealth(
        port: 51000,
        password: "secret",
        clientFactory: _HangingBodyClient.new,
        timeout: const Duration(milliseconds: 100),
      );
      expect(probe.healthy, isFalse);
      expect(probe.error, isA<TimeoutException>());
    });
  });

  group("spawnOpenCodeProcess", () {
    test("spawns with the frozen args and the password env var through the host", () async {
      final recording = _RecordingHostProcessService();
      final host = _SpawnFakeHost(
        processes: recording,
        environment: const <String, String>{"PATH": "/usr/bin", "HOME": "/home/alex"},
      );

      final spawned = await spawnOpenCodeProcess(
        host: host,
        executablePath: "/bin/opencode",
        port: 51000,
        password: "secret",
      );

      expect(spawned.pid, equals(4242));
      expect(recording.executable, equals("/bin/opencode"));
      expect(recording.arguments, equals(<String>["serve", "--port", "51000", "--hostname", "127.0.0.1"]));
      expect(recording.environment?["OPENCODE_SERVER_PASSWORD"], equals("secret"));
      expect(recording.environment?["PATH"], equals("/usr/bin"));
      expect(recording.environment?["HOME"], equals("/home/alex"));
      expect(recording.workingDirectory, isNull);
    });

    test("omits the password env var when password is null", () async {
      final recording = _RecordingHostProcessService();
      final host = _SpawnFakeHost(
        processes: recording,
        environment: const <String, String>{"PATH": "/usr/bin"},
      );

      await spawnOpenCodeProcess(
        host: host,
        executablePath: "/bin/opencode",
        port: 51000,
        password: null,
      );

      expect(recording.environment, isNotNull);
      expect(recording.environment!.containsKey("OPENCODE_SERVER_PASSWORD"), isFalse);
    });

    test("omits the password env var when password is empty", () async {
      final recording = _RecordingHostProcessService();
      final host = _SpawnFakeHost(
        processes: recording,
        environment: const <String, String>{"PATH": "/usr/bin"},
      );

      await spawnOpenCodeProcess(
        host: host,
        executablePath: "/bin/opencode",
        port: 51000,
        password: "",
      );

      expect(recording.environment, isNotNull);
      expect(recording.environment!.containsKey("OPENCODE_SERVER_PASSWORD"), isFalse);
    });
  });

  group("buildOpenCodeManagedRuntimeSpec", () {
    test("uses the hardened policy knobs active since the flip", () {
      final spec = buildOpenCodeManagedRuntimeSpec(
        host: _SpawnFakeHost(processes: _RecordingHostProcessService(), environment: const <String, String>{}),
        executablePath: "/bin/opencode",
        password: "secret",
        portPolicy: const ExplicitPortPolicy(port: 4096),
        probeClientFactory: () => MockClient((request) async => http.Response("", 200)),
      );

      expect(spec.recordTiming, equals(RuntimeRecordTiming.intentSideFile));
      expect(spec.validateRuntime, isNull);
      expect(spec.failOnEarlyChildExit, isTrue);
      final health = spec.healthPolicy;
      expect(health, isA<HealthDeadlinePolicy>());
      expect((health as HealthDeadlinePolicy).deadline, equals(const Duration(seconds: 30)));
      expect(health.pollInterval, equals(const Duration(milliseconds: 500)));
    });
  });

  group("buildOpenCodeRestartPolicy", () {
    test("builds the bounded pinned-port restart pacing", () {
      final policy = buildOpenCodeRestartPolicy();

      expect(policy, isA<BoundedRestartPolicy>());
      final bounded = policy as BoundedRestartPolicy;
      expect(bounded.maxAttempts, equals(3));
      expect(bounded.initialBackoff, equals(const Duration(seconds: 1)));
      expect(bounded.maxBackoff, equals(const Duration(seconds: 15)));
      expect(bounded.portReleaseTimeout, equals(const Duration(seconds: 10)));
      expect(bounded.portReleasePollInterval, equals(const Duration(milliseconds: 500)));
    });
  });
}

ProcessIdentity _identity({required int pid, required String? executablePath, required String? startMarker}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: executablePath,
    commandLine: executablePath == null ? "opencode" : "$executablePath serve",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );
}

class _SpawnFakeHost implements PluginHost {
  _SpawnFakeHost({required HostProcessService processes, required Map<String, String> environment})
    : _processes = processes,
      _environment = environment;

  final HostProcessService _processes;
  final Map<String, String> _environment;

  @override
  HostProcessService get processes => _processes;

  @override
  Map<String, String> get environment => _environment;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Accepts the request and returns 200 headers, but the body stream never
/// emits and never closes — a drain on it hangs forever.
class _HangingBodyClient extends http.BaseClient {
  final StreamController<List<int>> _body = StreamController<List<int>>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(_body.stream, 200);
  }

  @override
  void close() {
    _body.close().ignore();
    super.close();
  }
}

class _RecordingHostProcessService implements HostProcessService {
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
  String? workingDirectory;
  bool? runInShell;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    this.workingDirectory = workingDirectory;
    this.runInShell = runInShell;
    return _FakeSpawnedProcess(pid: 4242);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSpawnedProcess implements SpawnedProcess {
  _FakeSpawnedProcess({required this.pid});

  @override
  final int pid;

  final Completer<int> _exit = Completer<int>();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  ProcessIdentity get identity => ProcessIdentity(
    pid: pid,
    startMarker: null,
    executablePath: "/bin/opencode",
    commandLine: "/bin/opencode serve",
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
