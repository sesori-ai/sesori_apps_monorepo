import "dart:async";
import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _SettingsStore({required final List<String> events}) implements HostJsonStore {
  String? contents;
  bool failWrite = false;
  Completer<void>? writeStarted;
  Future<void>? writeGate;

  @override
  Future<void> write({required String name, required String contents}) async {
    expect(name, "settings.json");
    events.add("settings");
    writeStarted?.complete();
    await writeGate;
    if (failWrite) throw const FileSystemException("synthetic write interruption");
    this.contents = contents;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Commands({required final List<String> events}) implements CommandExecutor {
  CommandResult preflight = const CommandResult(exitCode: 0, stdout: "", stderr: "");
  bool failPermissions = false;
  bool timeoutPreflight = false;
  TimeoutException? timeoutFailure;
  StartAbortController? abortAfterPreflight;
  final List<({String executable, List<String> arguments, Map<String, String>? environment})> calls = [];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    calls.add((executable: executable, arguments: arguments, environment: environment));
    if (executable == "chmod") {
      events.add("chmod");
      expect(arguments.first, "700");
      expect(Directory(arguments.last).existsSync(), isTrue);
      if (failPermissions) return const CommandResult(exitCode: 1, stdout: "", stderr: "synthetic permission failure");
      if (!Platform.isWindows) {
        final result = await Process.run(
          executable,
          arguments,
          environment: environment,
          includeParentEnvironment: false,
        );
        expect(result.exitCode, 0);
      }
      return const CommandResult(exitCode: 0, stdout: "", stderr: "");
    }
    events.add("preflight");
    expect(timeout, isNotNull);
    expect(timeout! <= const Duration(seconds: 5), isTrue);
    expect(arguments.last, AntigravityProfileService.browserPreflightUrl);
    if (timeoutPreflight) throw const ProcessException("synthetic", [], "timed out");
    if (timeoutFailure case final failure?) throw failure;
    abortAfterPreflight?.abort();
    return preflight;
  }
}

AntigravityAuthenticationBudget budget() => AntigravityAuthenticationBudget(
  timeout: const Duration(seconds: 5),
  abortSignal: StartAbortSignal.never,
);

class _ProfileProcesses() implements HostProcessService {
  final List<({bool inherits, Map<String, String>? environment})> calls = [];

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    calls.add((inherits: includeParentEnvironment, environment: environment));
    return _ProfileProcess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileProcess() implements SpawnedProcess {
  @override
  Future<int> get exitCode async => 0;
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late List<String> events;
  late _SettingsStore store;
  late _Commands commands;
  late String home;
  const mac = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);
  const windows = PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64);

  AntigravityProfileService service({
    required PlatformTarget target,
    required String executable,
    required List<String> prefix,
  }) => AntigravityProfileService(
    repository: AntigravityProfileRepository(
      storage: AntigravityProfileStorage(geminiHome: home, settingsStore: store, commands: commands, target: target),
    ),
    target: target,
    browserExecutable: executable,
    browserPrefixArguments: prefix,
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync("antigravity-profile-test-");
    home = p.join(temp.path, "profile");
    events = [];
    store = _SettingsStore(events: events);
    commands = _Commands(events: events);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test("expired preparation does not dispatch and executor timeouts preserve identity", () async {
    final expired = AntigravityAuthenticationBudget(timeout: Duration.zero, abortSignal: StartAbortSignal.never);
    await expectLater(
      service(target: mac, executable: "/bridge", prefix: []).prepare(budget: expired, hostEnvironment: {}),
      throwsA(isA<TimeoutException>()),
    );
    expect(events, isEmpty);
    final failure = TimeoutException("synthetic command deadline");
    commands.timeoutFailure = failure;
    await expectLater(
      service(target: mac, executable: "/bridge", prefix: []).prepare(budget: budget(), hostEnvironment: {}),
      throwsA(same(failure)),
    );
    expect(temp.listSync(), isEmpty);
  });

  test("abort after preflight prevents profile mutation", () async {
    final abort = StartAbortController();
    commands.abortAfterPreflight = abort;
    await expectLater(
      service(target: mac, executable: "/bridge", prefix: []).prepare(
        budget: AntigravityAuthenticationBudget(timeout: const Duration(seconds: 5), abortSignal: abort.signal),
        hostEnvironment: {},
      ),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(events, ["preflight"]);
    expect(temp.listSync(), isEmpty);
  });

  test("cancellation awaits an in-flight atomic write then rejects its late success", () async {
    final abort = StartAbortController();
    final release = Completer<void>();
    store.writeStarted = Completer<void>();
    store.writeGate = release.future;
    var settled = false;
    final preparation = service(target: windows, executable: "/bridge", prefix: []).prepare(
      budget: AntigravityAuthenticationBudget(timeout: const Duration(seconds: 5), abortSignal: abort.signal),
      hostEnvironment: {},
    );
    final assertion = expectLater(preparation, throwsA(isA<PluginStartAbortedException>())).then((_) => settled = true);
    await store.writeStarted!.future;
    abort.abort();
    await Future<void>(() {});
    expect(settled, isFalse);
    release.complete();
    await assertion;
    expect(store.contents, contains("oauth-personal"));
  });

  test("read-only inspection is separate from profile preparation and never reads token contents", () {
    final inspection = AntigravityProfileInspectionService(
      repository: AntigravityProfileInspectionRepository(
        storage: const AntigravityProfileInspectionStorage(),
      ),
    );
    expect(inspection.inspect(geminiHome: home), AntigravityAuthenticationHint.authenticationRequired);
    expect(temp.listSync(), isEmpty);
    final token = File(p.join(home, "antigravity-acp", "acp_token.json"));
    token.parent.createSync(recursive: true);
    token.writeAsStringSync("deliberately not token JSON");
    expect(inspection.inspect(geminiHome: home), AntigravityAuthenticationHint.tokenPresent);
    expect(events, isEmpty);
    expect(store.contents, isNull);
  });

  test("preflight then 700 directories then typed atomic-store settings", () async {
    final prepared = await service(
      target: mac,
      executable: "/bridge",
      prefix: [],
    ).prepare(budget: budget(), hostEnvironment: {});
    expect(events, ["preflight", "chmod", "chmod", "settings"]);
    expect(store.contents, '{"auth":{"type":"oauth-personal"}}\n');
    expect(prepared.geminiHome, home);
    expect(prepared.environment["GEMINI_HOME"], home);
    expect(prepared.environment["AGY_ACP_FORCE_FILE_STORAGE"], "1");
    expect(prepared.environment["BROWSER"], "'/bridge' '--internal-browser-noop' '%s'");
    if (!Platform.isWindows) {
      for (final directory in [home, p.join(home, "antigravity-acp")]) {
        expect(FileStat.statSync(directory).mode & 0x1ff, 0x1c0);
      }
    }
    expect(() => prepared.environment["BROWSER"] = "ambient", throwsUnsupportedError);
  });

  test("hardens existing directories and rewrites non-personal settings", () async {
    Directory(p.join(home, "antigravity-acp")).createSync(recursive: true);
    store.contents = "synthetic stale settings";
    await service(target: mac, executable: "/bridge", prefix: []).prepare(budget: budget(), hostEnvironment: {});
    expect(events, ["preflight", "chmod", "chmod", "settings"]);
    expect(store.contents, contains("oauth-personal"));
  });

  test("strips credential/profile/browser aliases without mutating host environment", () async {
    final ambient = <String, String>{
      for (final key in [
        "google_api_key",
        "GOOGLE_APPLICATION_CREDENTIALS",
        "GoOgLe_Cloud_PROJECT",
        "GEMINI_HOME",
        "GEMINI_API_KEY",
        "AGY_ACP_ENABLE_OAUTH",
        "AGY_ACP_FORCE_FILE_STORAGE",
        "GCLOUD_PROJECT",
        "CLOUDSDK_CONFIG",
        "ANTIGRAVITY_HARNESS_PATH",
        "BROWSER",
        "PYTHONPATH",
        "PYTHONSTARTUP",
        "ELECTRON_RUN_AS_NODE",
        "GCP_PROJECT",
      ])
        key: "ambient-secret",
      "PATH": "/usr/bin:/bin",
      "HOME": "/synthetic/home",
      "HTTPS_PROXY": "https://proxy.invalid",
    };
    final original = Map<String, String>.of(ambient);
    final prepared = await service(
      target: mac,
      executable: "/bridge",
      prefix: [],
    ).prepare(budget: budget(), hostEnvironment: ambient);
    expect(ambient, original);
    expect(prepared.environment.values, isNot(contains("ambient-secret")));
    expect(prepared.environment["PATH"], ambient["PATH"]);
    expect(prepared.environment["HOME"], ambient["HOME"]);
    expect(prepared.environment["HTTPS_PROXY"], ambient["HTTPS_PROXY"]);
    expect(prepared.environment["PYTHONUNBUFFERED"], "1");
    expect(commands.calls.map((call) => call.environment), everyElement(prepared.environment));
    expect(commands.calls.skip(1).map((call) => call.executable), ["chmod", "chmod"]);
  });

  test("chmod resolves through the supplied PATH instead of a fixed filesystem location", () async {
    if (Platform.isWindows) return;
    final bin = Directory(p.join(temp.path, "coreutils"))..createSync();
    final marker = File(p.join(temp.path, "chmod-invoked"));
    final shim = File(p.join(bin.path, "chmod"));
    shim.writeAsStringSync('#!/bin/sh\nprintf invoked >> "${marker.path}"\n/bin/chmod "\$@"\n');
    final permission = await Process.run("/bin/chmod", ["700", shim.path]);
    expect(permission.exitCode, 0);
    await service(
      target: mac,
      executable: "/bridge",
      prefix: [],
    ).prepare(budget: budget(), hostEnvironment: {"PATH": bin.path});
    expect(marker.readAsStringSync(), "invokedinvoked");
    expect(FileStat.statSync(home).mode & 0x1ff, 0x1c0);
  });

  test("profile host executor disables inheritance for preflight and directory commands", () async {
    final processes = _ProfileProcesses();
    final profile = AntigravityProfileService(
      repository: AntigravityProfileRepository(
        storage: AntigravityProfileStorage(
          geminiHome: home,
          settingsStore: store,
          commands: HostProcessCommandExecutor(
            processes: processes,
            runInShell: false,
            includeParentEnvironment: false,
            maxCapturedOutputCharactersPerStream: 4096,
          ),
          target: mac,
        ),
      ),
      target: mac,
      browserExecutable: "/bridge",
      browserPrefixArguments: [],
    );
    final prepared = await profile.prepare(
      budget: budget(),
      hostEnvironment: {"GOOGLE_API_KEY": "synthetic", "PATH": "/usr/bin:/bin"},
    );
    expect(processes.calls, hasLength(3));
    expect(processes.calls.every((call) => !call.inherits), isTrue);
    expect(processes.calls.first.environment, prepared.environment);
    expect(processes.calls.first.environment, isNot(contains("GOOGLE_API_KEY")));
  });

  test("source invocation and apostrophes are shlex quoted, with exact preflight arguments", () async {
    final prepared = await service(
      target: mac,
      executable: "/a b/dart",
      prefix: ["--packages=/a b/package_config.json", "/a'b/bridge.dart"],
    ).prepare(budget: budget(), hostEnvironment: {});
    expect(
      prepared.environment["BROWSER"],
      "'/a b/dart' '--packages=/a b/package_config.json' '/a'\"'\"'b/bridge.dart' '--internal-browser-noop' '%s'",
    );
    expect(commands.calls.first.arguments, [
      "--packages=/a b/package_config.json",
      "/a'b/bridge.dart",
      BrowserNoop.argument,
      AntigravityProfileService.browserPreflightUrl,
    ]);
  });

  test("Windows keeps exact backslash invocation and relies on profile ACL without chmod", () async {
    final prepared = await service(
      target: windows,
      executable: r"C:\Program Files\bridge.exe",
      prefix: [],
    ).prepare(budget: budget(), hostEnvironment: {});
    expect(events, ["preflight", "settings"]);
    expect(prepared.environment["BROWSER"], r"'C:\Program Files\bridge.exe' '--internal-browser-noop' '%s'");
  });

  test("unsupported invocation blocks before processes or profile writes", () async {
    for (final executable in ["", "/a:b/bridge", "/a\n/bridge", "/a\u0000/bridge", "/a%s/bridge"]) {
      await expectLater(
        service(target: mac, executable: executable, prefix: []).prepare(budget: budget(), hostEnvironment: {}),
        throwsA(isA<AntigravityProfileException>()),
      );
    }
    await expectLater(
      service(
        target: windows,
        executable: "C:/a;b/bridge.exe",
        prefix: [],
      ).prepare(budget: budget(), hostEnvironment: {}),
      throwsA(isA<AntigravityProfileException>()),
    );
    expect(temp.listSync(), isEmpty);
    expect(events, isEmpty);
  });

  test("repository maps unsuccessful preflight facts without deciding preparation policy", () async {
    commands.preflight = const CommandResult(exitCode: 23, stdout: "unexpected", stderr: "synthetic loader failure");
    final repository = AntigravityProfileRepository(
      storage: AntigravityProfileStorage(geminiHome: home, settingsStore: store, commands: commands, target: mac),
    );
    final result = await repository.inspectBrowserCommand(
      budget: budget(),
      executable: "/bridge",
      arguments: [BrowserNoop.argument, AntigravityProfileService.browserPreflightUrl],
      environment: {},
    );
    expect(result.exitCode, 23);
    expect(result.hasOutput, isTrue);
    expect(result.diagnostics, same(commands.preflight));
    expect(result.toString(), isNot(contains("synthetic loader failure")));
    expect(events, ["preflight"]);
  });

  test("exit failure or any output blocks preparation", () async {
    for (final result in [
      const CommandResult(exitCode: 1, stdout: "", stderr: "synthetic loader failure"),
      const CommandResult(exitCode: 0, stdout: "unexpected", stderr: ""),
      const CommandResult(exitCode: 0, stdout: "", stderr: "unexpected"),
    ]) {
      commands.preflight = result;
      await expectLater(
        service(target: mac, executable: "/bridge", prefix: []).prepare(budget: budget(), hostEnvironment: {}),
        throwsA(
          isA<AntigravityProfileException>()
              .having((error) => error.cause, "original command result", same(result))
              .having((error) => error.message, "operation", contains("/bridge (exit code ${result.exitCode})"))
              .having((error) => error.toString(), "safe presentation", isNot(contains("synthetic loader failure")))
              .having((error) => error.toString(), "safe output presentation", isNot(contains("unexpected"))),
        ),
      );
    }
    expect(events, everyElement("preflight"));
    expect(temp.listSync(), isEmpty);
  });

  test("process failures retain original cause and never prepare", () async {
    commands.timeoutPreflight = true;
    await expectLater(
      service(target: mac, executable: "/bridge", prefix: []).prepare(budget: budget(), hostEnvironment: {}),
      throwsA(isA<AntigravityProfileException>().having((error) => error.cause, "cause", isA<ProcessException>())),
    );
    expect(temp.listSync(), isEmpty);
  });

  test("permission failure blocks settings and retains local operation context", () async {
    commands.failPermissions = true;
    await expectLater(
      service(target: mac, executable: "/bridge", prefix: []).prepare(budget: budget(), hostEnvironment: {}),
      throwsA(isA<AntigravityProfileException>().having((error) => error.cause.toString(), "cause", contains(home))),
    );
    expect(events, ["preflight", "chmod"]);
    expect(store.contents, isNull);
  });

  test("interrupted atomic settings write surfaces and keeps previous contents", () async {
    store.contents = "previous";
    store.failWrite = true;
    await expectLater(
      service(target: mac, executable: "/bridge", prefix: []).prepare(budget: budget(), hostEnvironment: {}),
      throwsA(isA<AntigravityProfileException>().having((error) => error.cause, "cause", isA<FileSystemException>())),
    );
    expect(store.contents, "previous");
  });
}
