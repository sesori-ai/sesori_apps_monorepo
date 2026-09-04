import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/grok_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("GrokPluginDescriptor", () {
    const stateDirectory = "/state";
    const config = PluginConfig(
      values: {GrokPluginDescriptor.binOption: GrokBinary.defaultBinary},
    );

    test("pins direct-CLI identity and capability facts", () {
      const descriptor = GrokPluginDescriptor();
      expect(descriptor.id, "grok");
      expect(descriptor.displayName, "Grok Build");
      expect(descriptor.projectOwnership, PluginProjectOwnership.bridgeDerived);
      expect(descriptor.sessionOptionsScope, PluginSessionOptionsScope.plugin);
      expect(descriptor.supportsPromptAttachments, isFalse);
      expect(GrokPluginDescriptor.minVersion, "1.0.5");
      expect(GrokPluginDescriptor.targetVersion, "1.0.5");
      expect(descriptor.options.single.name, GrokPluginDescriptor.binOption);
      expect(
        descriptor.managementCapabilities(config: config),
        isNot(contains(PluginControlCapability.install)),
        reason: "Grok owns its installer and update lifecycle",
      );
    });

    test("reports a current PATH runtime and its sanitized version", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess.completed(
            pid: 1,
            stdoutBytes: utf8.encode(
              "warning: helper runtime 9.9.9\n"
              "grok \u001b[32m1.0.5\u001b[0m (synthetic-build)\n",
            ),
            stderrBytes: const [],
            resultCode: 0,
          ),
        ],
        servesHeadlessAcp: false,
      );

      final result = await const GrokPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const {},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady.versioned(runtimeVersion: "1.0.5"));
      expect(processes.spawnedExecutables, ["grok"]);
      expect(processes.spawnedArguments, [
        const ["--version"],
      ]);
    });

    test("bounds noisy version output instead of parsing a version beyond the capture limit", () async {
      final oversizedPrefix = List.filled(70 * 1024, "x").join();
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess.completed(
            pid: 2,
            stdoutBytes: utf8.encode("$oversizedPrefix grok 1.0.5\n"),
            stderrBytes: const [],
            resultCode: 0,
          ),
        ],
        servesHeadlessAcp: false,
      );

      final result = await const GrokPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const {},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
    });

    test("reports missing, malformed, and outdated runtimes distinctly", () async {
      final missing = await const GrokPluginDescriptor().inspectSetup(
        config: config,
        processes: _ProbeProcessService(
          spawnError: const ProcessException("grok", ["--version"], "No such file", 2),
          processSequence: const [],
          servesHeadlessAcp: false,
        ),
        environment: const {},
        stateDirectory: stateDirectory,
      );
      final malformed = await const GrokPluginDescriptor().inspectSetup(
        config: config,
        processes: _ProbeProcessService(
          spawnError: null,
          processSequence: [
            _ProbeProcess.completed(
              pid: 2,
              stdoutBytes: utf8.encode("grok development build\n"),
              stderrBytes: const [],
              resultCode: 0,
            ),
          ],
          servesHeadlessAcp: false,
        ),
        environment: const {},
        stateDirectory: stateDirectory,
      );
      final outdated = await const GrokPluginDescriptor().inspectSetup(
        config: config,
        processes: _ProbeProcessService(
          spawnError: null,
          processSequence: [
            _ProbeProcess.completed(
              pid: 3,
              stdoutBytes: utf8.encode("grok 1.0.4 (old-build)\n"),
              stderrBytes: const [],
              resultCode: 0,
            ),
          ],
          servesHeadlessAcp: false,
        ),
        environment: const {},
        stateDirectory: stateDirectory,
      );

      expect(missing, isA<PluginSetupRuntimeMissing>());
      expect(malformed, isA<PluginSetupUnknown>());
      expect(outdated, isA<PluginSetupUnavailable>());
    });

    test("the explicit binary is authoritative for inspection and provisioning", () async {
      final inspectProcesses = _ProbeProcessService(
        spawnError: const ProcessException("/custom/grok", ["--version"], "No such file", 2),
        processSequence: const [],
        servesHeadlessAcp: false,
      );
      const explicitConfig = PluginConfig(
        values: {GrokPluginDescriptor.binOption: "/custom/grok"},
      );

      final setup = await const GrokPluginDescriptor().inspectSetup(
        config: explicitConfig,
        processes: inspectProcesses,
        environment: const {},
        stateDirectory: stateDirectory,
      );

      expect(setup, isA<PluginSetupRuntimeMissing>());
      expect((setup as PluginSetupRuntimeMissing).actionHint, contains("configured Grok Build binary path"));
      expect(inspectProcesses.spawnedExecutables, ["/custom/grok"]);

      final provisionProcesses = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess.completed(
            pid: 4,
            stdoutBytes: utf8.encode("grok 1.0.5 (current)\n"),
            stderrBytes: const [],
            resultCode: 0,
          ),
        ],
        servesHeadlessAcp: false,
      );
      final events = await const GrokPluginDescriptor()
          .ensureRuntime(
            host: _StartPluginHost(
              processes: provisionProcesses,
              config: explicitConfig,
              provisionedRuntimePath: null,
              startAborted: StartAbortSignal.never,
            ),
          )
          .toList();

      expect(
        events,
        [isA<ProvisionReady>().having((event) => event.binaryPath, "binaryPath", "/custom/grok")],
      );
      expect(provisionProcesses.spawnedExecutables, ["/custom/grok"]);
    });

    test("ensureRuntime revalidates PATH and reports an outdated runtime", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess.completed(
            pid: 5,
            stdoutBytes: utf8.encode("grok 1.0.4 (old-build)\n"),
            stderrBytes: const [],
            resultCode: 0,
          ),
        ],
        servesHeadlessAcp: false,
      );

      final events = await const GrokPluginDescriptor()
          .ensureRuntime(
            host: _StartPluginHost(
              processes: processes,
              config: config,
              provisionedRuntimePath: null,
              startAborted: StartAbortSignal.never,
            ),
          )
          .toList();

      expect(events, [isA<ProvisionFailed>().having((event) => event.message, "message", contains("too old"))]);
      expect(processes.spawnedArguments, [
        const ["--version"],
      ]);
    });

    test("an aborted provision does not launch a probe", () async {
      final abort = StartAbortController()..abort();
      final processes = _ProbeProcessService(
        spawnError: StateError("must not spawn"),
        processSequence: const [],
        servesHeadlessAcp: false,
      );

      await expectLater(
        const GrokPluginDescriptor()
            .ensureRuntime(
              host: _StartPluginHost(
                processes: processes,
                config: config,
                provisionedRuntimePath: null,
                startAborted: abort.signal,
              ),
            )
            .toList(),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(processes.spawnedExecutables, isEmpty);
    });

    test("start uses the resolved binary and clean shutdown reaps the owned agent", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: const [],
        servesHeadlessAcp: true,
      );

      final plugin = await const GrokPluginDescriptor().start(
        _StartPluginHost(
          processes: processes,
          config: config,
          provisionedRuntimePath: "/resolved/grok",
          startAborted: StartAbortSignal.never,
        ),
      );

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(plugin.describe().endpoint, "/resolved/grok");
      expect(processes.spawnedExecutables, ["/resolved/grok"]);
      expect(processes.spawnedArguments, [
        GrokBinary.launchSpec(binary: "grok", cwd: null, environment: const {}).args,
      ]);

      await plugin.shutdown(budget: null);
      await plugin.shutdown(budget: null);
      expect(plugin.currentStatus, isA<PluginStopped>());
      expect(processes.gracefulSignals, hasLength(1));
    });

    test("interactive-only authentication degrades only Grok with local guidance", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: const [],
        servesHeadlessAcp: false,
        servesInteractiveAcp: true,
      );

      final plugin = await const GrokPluginDescriptor().start(
        _StartPluginHost(
          processes: processes,
          config: config,
          provisionedRuntimePath: "/resolved/grok",
          startAborted: StartAbortSignal.never,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final status = plugin.currentStatus as PluginDegraded;
      expect(status.recoverable, isTrue);
      expect(status.requiresUserAction, isTrue);
      expect(status.userActionHint, contains("grok login"));
      expect(processes.receivedAuthenticate, isFalse);
      await plugin.shutdown(budget: null);
    });

    test("an unexpected crash degrades and the stable API reconnects", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: const [],
        servesHeadlessAcp: true,
      );
      final plugin = await const GrokPluginDescriptor().start(
        _StartPluginHost(
          processes: processes,
          config: config,
          provisionedRuntimePath: "/resolved/grok",
          startAborted: StartAbortSignal.never,
        ),
      );
      final api = plugin.api as GrokPlugin;
      final firstApi = plugin.api;

      processes.acpProcesses.single.exit(1);
      await _settleUntil(() => plugin.currentStatus is PluginDegraded);
      expect(plugin.currentStatus, isA<PluginDegraded>());

      expect(await api.ensureConnected(), isTrue);
      await _settleUntil(() => plugin.currentStatus is PluginReady);
      expect(plugin.currentStatus, isA<PluginReady>());
      expect(identical(plugin.api, firstApi), isTrue);
      expect(processes.acpProcesses, hasLength(2));

      await plugin.shutdown(budget: null);
      expect(processes.acpProcesses.last.exitCode, completion(-15));
    });
  });
}

Future<void> _settleUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _StartPluginHost({
  @override required final HostProcessService processes,
  @override required final PluginConfig config,
  @override required final String? provisionedRuntimePath,
  @override required final StartAbortSignal startAborted,
}) implements PluginHost {
  @override
  Map<String, String> get environment => const {"HOME": "/tmp"};

  @override
  ServerClock get clock => const _ImmediateClock();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _ImmediateClock() extends ServerClock {
  @override
  DateTime now() => DateTime.utc(2026, 8, 28);

  @override
  Future<void> delay({required Duration duration}) => Future<void>.value();
}

class _ProbeProcessService({
  required final Object? spawnError,
  required final List<_ProbeProcess> processSequence,
  required final bool servesHeadlessAcp,
  final bool servesInteractiveAcp = false,
}) implements HostProcessService {
  int _nextProcess = 0;
  int _nextAcpPid = 100;
  final List<_AcpProcess> acpProcesses = [];
  final List<String> spawnedExecutables = [];
  final List<List<String>> spawnedArguments = [];
  final List<int> gracefulSignals = [];
  bool receivedAuthenticate = false;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    spawnedExecutables.add(executable);
    spawnedArguments.add(List.unmodifiable(arguments));
    final error = spawnError;
    if (error != null) throw error;
    if ((servesHeadlessAcp || servesInteractiveAcp) &&
        arguments.length == 4 &&
        arguments[0] == "--no-auto-update" &&
        arguments[1] == "agent" &&
        arguments[2] == "--no-leader" &&
        arguments[3] == "stdio") {
      final process = _AcpProcess(
        pid: _nextAcpPid++,
        headlessAuthentication: servesHeadlessAcp,
        onAuthenticate: () => receivedAuthenticate = true,
      );
      acpProcesses.add(process);
      return process;
    }
    if (_nextProcess < processSequence.length) return processSequence[_nextProcess++];
    throw StateError("No canned process remains for $executable ${arguments.join(' ')}");
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulSignals.add(pid);
    for (final process in acpProcesses.where((candidate) => candidate.pid == pid)) {
      process.exit(-15);
    }
    return _signal(
      pid: pid,
      requestedSignal: ShutdownSignal.graceful,
      deliveredSignal: ProcessSignal.sigterm,
    );
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    for (final process in acpProcesses.where((candidate) => candidate.pid == pid)) {
      process.exit(-9);
    }
    return _signal(
      pid: pid,
      requestedSignal: ShutdownSignal.force,
      deliveredSignal: ProcessSignal.sigkill,
    );
  }

  SignalResult _signal({
    required int pid,
    required ShutdownSignal requestedSignal,
    required ProcessSignal deliveredSignal,
  }) => SignalResult(
    pid: pid,
    requestedSignal: requestedSignal,
    deliveredSignal: deliveredSignal,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 28),
  );
}

class _ProbeProcess.completed({
  @override required final int pid,
  required final List<int> stdoutBytes,
  required final List<int> stderrBytes,
  required final int resultCode,
}) implements SpawnedProcess {
  final List<int> _stdoutBytes = stdoutBytes;
  final List<int> _stderrBytes = stderrBytes;
  final int _completedExitCode = resultCode;

  @override
  Future<int> get exitCode => Future.value(_completedExitCode);

  @override
  Stream<List<int>> get stdout => Stream.value(_stdoutBytes);

  @override
  Stream<List<int>> get stderr => Stream.value(_stderrBytes);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
}

class _AcpProcess({
  @override required final int pid,
  required final bool headlessAuthentication,
  required final void Function() onAuthenticate,
}) implements SpawnedProcess {
  this {
    stdin = IOSink(_InputSink(onLine: _handleLine));
  }

  final StreamController<List<int>> _stdout = StreamController();
  final Completer<int> _exit = Completer();

  @override
  late final IOSink stdin;

  void _handleLine(String line) {
    final frame = jsonDecode(line) as Map<String, dynamic>;
    switch (frame["method"]) {
      case AcpMethods.initialize:
        _respond(
          id: frame["id"],
          result: {
            "protocolVersion": 1,
            "agentCapabilities": {
              "loadSession": true,
              "sessionCapabilities": {
                "list": <String, dynamic>{},
                "resume": <String, dynamic>{},
                "close": <String, dynamic>{},
              },
            },
            "authMethods": [
              if (headlessAuthentication)
                {"id": "cached_token", "name": "Cached token"}
              else
                {"id": "grok.com", "name": "Interactive login"},
            ],
            "_meta": {
              "grokShell": true,
              "agentVersion": "1.0.5",
              "modelState": {
                "currentModelId": "synthetic:model",
                "availableModels": [
                  {
                    "modelId": "synthetic:model",
                    "name": "Synthetic model",
                    "_meta": {
                      "supportsReasoningEffort": false,
                      "reasoningEfforts": <Object?>[],
                    },
                  },
                ],
              },
            },
          },
        );
      case AcpMethods.authenticate:
        onAuthenticate();
        _respond(id: frame["id"], result: <String, dynamic>{});
    }
  }

  void _respond({required Object? id, required Map<String, dynamic> result}) {
    _stdout.add(utf8.encode("${jsonEncode({"jsonrpc": "2.0", "id": id, "result": result})}\n"));
  }

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
    if (!_stdout.isClosed) unawaited(_stdout.close());
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
}

class _InputSink({required final void Function(String line) onLine}) implements StreamConsumer<List<int>> {
  final StringBuffer _buffer = StringBuffer();

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final bytes in stream) {
      _buffer.write(utf8.decode(bytes));
      final lines = _buffer.toString().split("\n");
      _buffer
        ..clear()
        ..write(lines.removeLast());
      lines.where((line) => line.isNotEmpty).forEach(onLine);
    }
  }

  @override
  Future<void> close() async {}
}
