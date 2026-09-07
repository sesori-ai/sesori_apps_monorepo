import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _Input({required final void Function({required Map<String, dynamic> frame}) received}) extends CapturingIOSink {
  @override
  void add(List<int> data) {
    super.add(data);
    received(frame: frames.last);
  }
}

enum _Outcome() {
  complete,
  stall,
  exit,
}

class _Process() implements AcpProcessHandle {
  final out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final exited = Completer<int>();
  final authenticating = Completer<void>();
  _Outcome outcome = _Outcome.complete;
  String? challenge;
  StartAbortController? abortOnKill;
  @override
  late final stdin = _Input(
    received: ({required frame}) {
      if (frame["method"] == "initialize") {
        final encoded = jsonEncode({
          "id": frame["id"],
          "result": {
            "protocolVersion": 1,
            "authMethods": [
              {"id": "enterprise", "name": "Enterprise"},
              {"id": "oauth-personal", "name": "Personal"},
            ],
          },
        });
        out.add(utf8.encode("$encoded\n"));
      } else {
        expect(frame["method"], "authenticate");
        expect(frame["params"], {"methodId": "oauth-personal"});
        authenticating.complete();
        if (challenge case final text?) {
          final bytes = utf8.encode("${AntigravityAuthorizationMapper.prefix}$text\r\n");
          out.add(bytes.sublist(0, 12));
          out.add(bytes.sublist(12));
          err.add(utf8.encode("state=synthetic-state code=synthetic-code\n"));
          err.add(utf8.encode("useful diagnostic\n"));
        }
        switch (outcome) {
          case _Outcome.complete:
            out.add(utf8.encode('{"id":${frame["id"]},"result":{}}\n'));
          case _Outcome.exit:
            exited.complete(17);
          case _Outcome.stall:
            break;
        }
      }
    },
  );
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => err.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    abortOnKill?.abort();
    if (!exited.isCompleted) exited.complete(-15);
    return true;
  }

  Future<void> close() async {
    await out.close();
    await err.close();
  }
}

class _Loopback() implements AntigravityLoopbackClient {
  int status = 200;
  Object? failure;
  @override
  Future<int> forward({required Uri callbackUri, required AntigravityAuthenticationBudget budget}) async {
    if (failure case final error?) throw error;
    return status;
  }

  @override
  void dispose() {}
}

void main() {
  const pair = AntigravityRuntimePair(
    serverPath: "/runtime/agy_acp_server.par",
    harnessPath: "/runtime/localharness_external",
    target: PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
  );
  const url =
      "https://accounts.google.com/o/oauth2/v2/auth?state=synthetic-state&response_type=code&"
      "redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2F";
  late _Process process;
  late _Loopback loopback;
  late AntigravityAuthenticationRepository repository;
  late List<AcpLaunchSpec> launches;
  setUp(() {
    process = _Process();
    loopback = _Loopback();
    launches = [];
    repository = AntigravityAuthenticationRepository(
      acpApi: AntigravityAcpApi(
        processFactory: (launch) async {
          launches.add(launch);
          return process;
        },
        stderrInterceptor: AcpOutputInterceptor(
          maxLineBytes: 65536,
          consumeLine: const AntigravityStderrMapper().consumeLine,
        ),
      ),
      loopbackClient: loopback,
      authorizationMapper: const AntigravityAuthorizationMapper(),
      launchSpecBuilder: const AntigravityLaunchSpecBuilder(),
    );
  });
  tearDown(() => repository.dispose());

  Future<void> authenticate({required AntigravityAuthenticationBudget budget}) =>
      repository.authenticate(pair: pair, environment: const {"GEMINI_HOME": "/synthetic/profile"}, budget: budget);

  AntigravityAuthenticationBudget budget() =>
      AntigravityAuthenticationBudget(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);

  test("authorization mapper consumes only exact prefix and bounds/parses without exposing failures", () {
    const mapper = AntigravityAuthorizationMapper();
    expect(mapper.parseLine(line: utf8.encode("ordinary diagnostic\n")), isNull);
    expect(mapper.parseLine(line: utf8.encode("${AntigravityAuthorizationMapper.prefix}$url\n")), Uri.parse(url));
    for (final payload in ["", "https://a.invalid/ a", "x" * 16385, "http://[synthetic-state"]) {
      expect(
        () => mapper.parseLine(line: utf8.encode("${AntigravityAuthorizationMapper.prefix}$payload\n")),
        throwsA(
          isA<AntigravityAuthenticationException>().having(
            (error) => error.toString(),
            "privacy",
            isNot(contains(payload.isEmpty ? "synthetic-state" : payload)),
          ),
        ),
      );
    }
  });

  test("personal handshake maps fragmented challenge before logging and cleans up", () async {
    final logs = BufferingStdout();
    final requests = <Uri>[];
    final subscription = repository.authorizations.listen(requests.add);
    process.challenge = url;
    await IOOverrides.runZoned(() => authenticate(budget: budget()), stderr: () => logs);
    expect(requests, [Uri.parse(url)]);
    expect(logs.text, isNot(contains("synthetic-state")));
    expect(logs.text, isNot(contains("synthetic-code")));
    expect(launches.single.includeParentEnvironment, isFalse);
    expect(launches.single.environment[AntigravityRelease.harnessPathEnvironmentKey], pair.harnessPath);
    expect(await process.exitCode, -15);
    await subscription.cancel();
    await process.close();
  });

  test("already authenticated or same-host completion needs no challenge", () async {
    final requests = <Uri>[];
    final subscription = repository.authorizations.listen(requests.add);
    await authenticate(budget: budget());
    expect(requests, isEmpty);
    expect(await process.exitCode, -15);
    await subscription.cancel();
    await process.close();
  });

  test("timeout, abort and process exit settle after cleanup", () async {
    for (final mode in ["timeout", "abort", "exit"]) {
      process = _Process()..outcome = mode == "exit" ? _Outcome.exit : _Outcome.stall;
      final abort = StartAbortController();
      final assertion = expectLater(
        authenticate(
          budget: AntigravityAuthenticationBudget(
            timeout: mode == "timeout" ? const Duration(milliseconds: 30) : const Duration(seconds: 2),
            abortSignal: abort.signal,
          ),
        ),
        throwsA(switch (mode) {
          "timeout" => isA<TimeoutException>(),
          "abort" => isA<PluginStartAbortedException>(),
          _ => isA<AntigravityAuthenticationException>().having(
            (error) => error.cause.toString(),
            "exit",
            contains("17"),
          ),
        }),
      );
      await process.authenticating.future;
      if (mode == "abort") abort.abort();
      await assertion;
      expect(await process.exitCode, mode == "exit" ? 17 : -15);
      await process.close();
    }
  });

  test("malformed consumed challenge fails safely rather than leaking or hanging", () async {
    process.challenge = "http://[synthetic-state";
    process.outcome = _Outcome.stall;
    final logs = BufferingStdout();
    await IOOverrides.runZoned(() async {
      await expectLater(authenticate(budget: budget()), throwsA(isA<AntigravityAuthenticationException>()));
    }, stderr: () => logs);
    expect(logs.text, isNot(contains("synthetic-state")));
    expect(await process.exitCode, -15);
    await process.close();
  });

  test("post-cleanup cancellation rejects successful ACP result", () async {
    final abort = StartAbortController();
    process.abortOnKill = abort;
    await expectLater(
      authenticate(
        budget: AntigravityAuthenticationBudget(
          timeout: const Duration(seconds: 2),
          abortSignal: abort.signal,
        ),
      ),
      throwsA(isA<PluginStartAbortedException>()),
    );
    await process.close();
  });

  test("HTTP outcomes normalize before service policy; original causes stay private", () async {
    for (final status in [200, 204, 302, 500]) {
      loopback.status = status;
      final result = await repository.forward(callbackUri: Uri.parse(url), budget: budget());
      expect(result, status < 300 ? isA<AntigravityCallbackAccepted>() : isA<AntigravityCallbackRejected>());
    }
    const cause = FormatException("synthetic-state");
    loopback.failure = cause;
    await expectLater(
      repository.forward(callbackUri: Uri.parse(url), budget: budget()),
      throwsA(
        isA<AntigravityAuthenticationException>()
            .having((error) => error.cause, "cause", same(cause))
            .having((error) => error.toString(), "presentation", isNot(contains("synthetic-state"))),
      ),
    );
    // No process was requested in this boundary-only test.
  });
}
