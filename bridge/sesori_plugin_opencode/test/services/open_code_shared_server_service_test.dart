import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/api/open_code_service_command_api.dart";
import "package:opencode_plugin/src/api/open_code_service_registration_api.dart";
import "package:opencode_plugin/src/repositories/open_code_shared_server_repository.dart";
import "package:opencode_plugin/src/services/open_code_shared_server_service.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show HostProcessCommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late Directory stateRoot;
  late _ScriptedCli cli;
  late StartAbortController abort;

  setUp(() {
    stateRoot = Directory.systemTemp.createTempSync("opencode-shared-service-");
    abort = StartAbortController();
    cli = _ScriptedCli()
      ..outputs.addAll({
        "--version": (exitCode: 0, stdout: "opencode v2.0.25\n"),
        "service get disabled": (exitCode: 0, stdout: "false\n"),
        "service start": (exitCode: 0, stdout: "http://127.0.0.1:49374\n"),
      })
      ..onServiceStart = () => register(stateRoot: stateRoot);
  });

  tearDown(() => stateRoot.deleteSync(recursive: true));

  Future<String?> acquire({String? binary = "/bin/opencode"}) async {
    final service = OpenCodeSharedServerService(
      repository: OpenCodeSharedServerRepository(
        registrationApi: const OpenCodeServiceRegistrationApi(),
        commandApi: OpenCodeServiceCommandApi(
          executor: HostProcessCommandExecutor(
            processes: cli,
            runInShell: false,
            includeParentEnvironment: true,
            maxCapturedOutputCharactersPerStream: null,
          ),
        ),
        probeClientFactory: () =>
            MockClient((_) async => http.Response(jsonEncode({"version": "2.0.25", "pid": 321}), 200)),
      ),
    );
    final endpoint = await service.acquire(
      binary: binary,
      environment: {"XDG_STATE_HOME": stateRoot.path},
      startAborted: abort.signal,
    );
    return endpoint?.url;
  }

  test("uses a running service without running the CLI", () async {
    register(stateRoot: stateRoot);

    expect(await acquire(), equals("http://127.0.0.1:49374"));
    expect(cli.commands, isEmpty);
  });

  test("starts the service when none is registered and attaches to it", () async {
    expect(await acquire(), equals("http://127.0.0.1:49374"));
    expect(cli.commands, equals(["--version", "service get disabled", "service start"]));
  });

  test("runs nothing without a resolved binary", () async {
    expect(await acquire(binary: null), isNull);
    expect(cli.commands, isEmpty);
  });

  test("keeps OpenCode 1 on a private server", () async {
    cli.outputs["--version"] = (exitCode: 0, stdout: "1.14.30\n");

    expect(await acquire(), isNull);
    expect(cli.commands, equals(["--version"]));
  });

  test("respects OpenCode's own disabled setting", () async {
    cli.outputs["service get disabled"] = (exitCode: 0, stdout: "true\n");

    expect(await acquire(), isNull);
    expect(cli.commands, isNot(contains("service start")));
  });

  test("does not start when the disabled setting cannot be read", () async {
    cli.outputs["service get disabled"] = (exitCode: 0, stdout: "maybe\n");

    expect(await acquire(), isNull);
    expect(cli.commands, isNot(contains("service start")));
  });

  test("falls back when the start fails", () async {
    cli.outputs["service start"] = (exitCode: 1, stdout: "");

    expect(await acquire(), isNull);
  });

  test("falls back when the started service is still not discoverable", () async {
    cli.onServiceStart = null;

    expect(await acquire(), isNull);
    expect(cli.commands, contains("service start"));
  });

  test("an aborted bridge start aborts instead of falling back", () async {
    cli.onServiceStart = abort.abort;

    await expectLater(acquire(), throwsA(isA<PluginStartAbortedException>()));
  });
}

void register({required Directory stateRoot}) {
  File(p.join(stateRoot.path, "opencode", "service.json"))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({"url": "http://127.0.0.1:49374", "pid": 321, "password": "service-secret"}));
}

/// The OpenCode CLI: each command prints its scripted output and exits at once.
class _ScriptedCli() implements HostProcessService {
  final Map<String, ({int exitCode, String stdout})> outputs = {};
  final List<String> commands = <String>[];
  void Function()? onServiceStart;
  int _nextPid = 100;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    final command = arguments.join(" ");
    commands.add(command);
    if (command == "service start") onServiceStart?.call();
    final output = outputs[command] ?? (exitCode: 1, stdout: "");
    return _ExitedProcess(pid: _nextPid++, exitCode: Future.value(output.exitCode), stdoutText: output.stdout);
  }

  /// An abort force-stops the running command; the scripted one already exited.
  @override
  Future<SignalResult> signalForce({required int pid}) async => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.force,
    deliveredSignal: ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 10, 8),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExitedProcess({
  @override required final int pid,
  @override required final Future<int> exitCode,
  required final String _stdoutText,
}) implements SpawnedProcess {
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(_stdoutText));

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
