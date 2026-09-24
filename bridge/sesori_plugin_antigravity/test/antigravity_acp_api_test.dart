import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class const _UnusedCommands() implements CommandExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VersionCommands({required final CommandResult result}) implements CommandExecutor {
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
  Duration? timeout;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    this.executable = executable;
    this.arguments = List<String>.unmodifiable(arguments);
    this.environment = environment == null ? null : Map<String, String>.unmodifiable(environment);
    this.timeout = timeout;
    return result;
  }
}

class _AbortAfterInitializeSignal() implements StartAbortSignal {
  int _polls = 0;

  @override
  bool get isAborted => ++_polls >= 4;

  @override
  Future<void> get whenAborted => Completer<void>().future;
}

void main() {
  late FakeAcpProcess process;
  late List<AcpLaunchSpec> launchSpecs;
  late AntigravityAcpApi api;

  setUp(() {
    process = FakeAcpProcess();
    launchSpecs = [];
    api = AntigravityAcpApi(
      commands: const _UnusedCommands(),
      stderrInterceptor: AcpOutputInterceptor(
        maxLineBytes: 65536,
        consumeLine: const AntigravityStderrMapper().consumeLine,
      ),
      processFactory: (spec) async {
        launchSpecs.add(spec);
        return process;
      },
    );
  });
  tearDown(() => process.close());

  test("version runs only the bounded helper command and sanitizes its build label", () async {
    const timeout = Duration(seconds: 1);
    final commands = _VersionCommands(
      result: const CommandResult(
        exitCode: 0,
        stdout: "diagnostic\nBuild label: ${AntigravityRelease.agentVersion}\n",
        stderr: "ignored",
      ),
    );
    api = AntigravityAcpApi(
      commands: commands,
      stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: ({required line}) => false),
      processFactory: (_) async => process,
    );

    final version = await api.version(
      serverPath: "/runtime/agy_acp_server.par",
      environment: const {"GEMINI_HOME": "/isolated"},
      timeout: timeout,
    );

    expect((version.exitCode, version.buildLabel), (0, AntigravityRelease.agentVersion));
    expect(commands.executable, "/runtime/agy_acp_server.par");
    expect(commands.arguments, const ["--version"]);
    expect(commands.environment, const {"GEMINI_HOME": "/isolated"});
    expect(commands.timeout, timeout);
    expect(launchSpecs, isEmpty);
  });

  for (final label in const ["1.2.1", "agy_acp_server_1.1.1", "agy_acp_server_20260818_01_RC01"]) {
    test("version accepts the official build label $label", () async {
      api = AntigravityAcpApi(
        commands: _VersionCommands(
          result: CommandResult(exitCode: 0, stdout: "Build label: $label\n", stderr: ""),
        ),
        stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: ({required line}) => false),
        processFactory: (_) async => process,
      );

      final version = await api.version(
        serverPath: "/runtime/agy_acp_server.par",
        environment: const {},
        timeout: const Duration(seconds: 1),
      );

      expect(version.buildLabel, label);
    });
  }

  test("version rejects blank and unsafe build labels", () async {
    for (final output in [
      "Build label:   \n",
      "Build label: private@example.com\n",
      "Build label: 1.2.1 private@example.com\n",
      "Build label: 20260818_01_RC01\n",
      "development build\n",
    ]) {
      api = AntigravityAcpApi(
        commands: _VersionCommands(
          result: CommandResult(exitCode: 0, stdout: output, stderr: ""),
        ),
        stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: ({required line}) => false),
        processFactory: (_) async => process,
      );

      final version = await api.version(
        serverPath: "/runtime/agy_acp_server.par",
        environment: const {},
        timeout: const Duration(seconds: 1),
      );

      expect(version.buildLabel, isNull, reason: output);
    }
  });

  for (final authenticating in [false, true]) {
    test("${authenticating ? 'authentication' : 'probe'} abort awaits and reaps a late spawn", () async {
      final spawn = Completer<AcpProcessHandle>();
      final spawning = Completer<void>();
      final abort = StartAbortController();
      api = AntigravityAcpApi(
        commands: const _UnusedCommands(),
        processFactory: (_) {
          spawning.complete();
          return spawn.future;
        },
        stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: ({required line}) => false),
      );
      var settled = false;
      final assertion = expectLater(
        authenticating
            ? api.authenticate(
                launchSpec: const AcpLaunchSpec(command: "/synthetic/agent", args: [], includeParentEnvironment: false),
                stdoutInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: ({required line}) => false),
                budget: AntigravityAuthenticationBudget(timeout: const Duration(seconds: 2), abortSignal: abort.signal),
              )
            : api.initializeOnly(
                launchSpec: const AcpLaunchSpec(command: "/synthetic/agent", args: [], includeParentEnvironment: false),
                timeout: const Duration(seconds: 2),
                abortSignal: abort.signal,
              ),
        throwsA(isA<PluginStartAbortedException>()),
      ).then((_) => settled = true);
      await spawning.future;
      abort.abort();
      await Future<void>(() {});
      expect(settled, isFalse);
      spawn.complete(process);
      await assertion;
      expect(await process.exitCode, -15);
      expect(process.written, isEmpty);
    });
  }

  Future<Map<String, dynamic>> waitForInitialize() async {
    for (var attempt = 0; attempt < 400; attempt++) {
      final frames = process.written.where((frame) => frame["method"] == "initialize");
      if (frames.isNotEmpty) return frames.last;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("agent never received initialize");
  }

  Future<AntigravityInitializeDto> probe({required Duration timeout, required StartAbortSignal abortSignal}) =>
      api.initializeOnly(
        launchSpec: const AcpLaunchSpec(
          includeParentEnvironment: true,
          command: "/runtime/agy_acp_server.par",
          args: [],
        ),
        timeout: timeout,
        abortSignal: abortSignal,
      );

  Map<String, dynamic> initializeResult() => {
    "protocolVersion": 1,
    "agentInfo": {
      "name": "antigravity-acp",
      "title": "Google Antigravity",
      "version": AntigravityRelease.agentVersion,
    },
    "agentCapabilities": {
      "loadSession": true,
      "sessionCapabilities": {"list": <String, dynamic>{}, "resume": <String, dynamic>{}},
      "auth": {"logout": <String, dynamic>{}},
    },
    "authMethods": [
      {"id": "oauth-personal", "name": "Log in with Google"},
    ],
  };

  test("runs initialize-only and cleans up without authenticating", () async {
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);
    final initialize = await waitForInitialize();
    process.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": initializeResult()});

    final result = await probing;
    expect(launchSpecs.single.command, "/runtime/agy_acp_server.par");
    expect((result.agentInfo?.name, result.authMethods?.single.id), ("antigravity-acp", "oauth-personal"));
    expect(process.written.where((frame) => frame["method"] == "authenticate"), isEmpty);
    expect(await process.exitCode, -15);
  });

  test("surfaces malformed initialize data and cleans up", () async {
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);
    final initialize = await waitForInitialize();
    process.emit({
      "jsonrpc": "2.0",
      "id": initialize["id"],
      "result": {...initializeResult(), "protocolVersion": "invalid"},
    });
    await expectLater(probing, throwsA(isA<TypeError>()));
    expect(await process.exitCode, -15);
  });

  test("bounds an unresponsive initialize request", () async {
    final probing = probe(timeout: const Duration(milliseconds: 250), abortSignal: StartAbortSignal.never);
    await waitForInitialize();
    await expectLater(probing, throwsA(isA<TimeoutException>()));
    expect(await process.exitCode, -15);
  });

  test("aborts an in-flight initialize and cleans up", () async {
    final controller = StartAbortController();
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: controller.signal);
    await waitForInitialize();
    controller.abort();
    await expectLater(probing, throwsA(isA<PluginStartAbortedException>()));
    expect(await process.exitCode, -15);
  });

  test("rechecks cancellation after initialize completes", () async {
    final probing = probe(
      timeout: const Duration(seconds: 2),
      abortSignal: _AbortAfterInitializeSignal(),
    );
    final initialize = await waitForInitialize();
    process.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": initializeResult()});
    await expectLater(probing, throwsA(isA<PluginStartAbortedException>()));
    expect(await process.exitCode, -15);
  });

  test("preserves process-exit context and cleans up", () async {
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);
    await waitForInitialize();
    process.exit(23);
    await expectLater(
      probing,
      throwsA(isA<AcpRpcException>().having((error) => error.message, "message", contains("23"))),
    );
    expect(await process.exitCode, 23);
  });
}
