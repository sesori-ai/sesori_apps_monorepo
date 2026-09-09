import "dart:async";
import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _ValidationCall({
  required final String serverPath,
  required final Map<String, String> environment,
  required final String workingDirectory,
  required final PlatformTarget target,
  required final Duration timeout,
  required final StartAbortSignal abortSignal,
});

class _RuntimeService({required final AntigravityRuntimeResolution result}) implements AntigravityRuntimeService {
  _ValidationCall? call;

  @override
  Future<AntigravityRuntimeResolution> validateManagedCandidate({
    required String serverPath,
    required Map<String, String> probeEnvironment,
    required String workingDirectory,
    required PlatformTarget target,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    call = _ValidationCall(
      serverPath: serverPath,
      environment: probeEnvironment,
      workingDirectory: workingDirectory,
      target: target,
      timeout: timeout,
      abortSignal: abortSignal,
    );
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RuntimeCandidateValidationContext _context({required StartAbortSignal abortSignal}) =>
    RuntimeCandidateValidationContext(
      executablePath: "/managed/staging/candidate/agy_acp_server.par",
      workingDirectory: "/managed/staging/validation-cwd",
      stateDirectory: "/managed/staging/validation-state",
      environment: const {
        "PATH": "/usr/bin:/bin",
        "GOOGLE_API_KEY": "ambient-google-secret",
        "gemini_token": "ambient-gemini-secret",
        "ANTIGRAVITY_HARNESS_PATH": "/ambient/harness",
        "BROWSER": "/ambient/browser",
        "PYTHONPATH": "/ambient/python",
        "SAFE_VALUE": "retained",
      },
      abortSignal: abortSignal,
    );

void main() {
  const pair = AntigravityRuntimePair(
    serverPath: "/managed/staging/candidate/agy_acp_server.par",
    harnessPath: "/managed/staging/candidate/localharness_external",
    target: PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
  );

  test(
    "uses isolated state, staging cwd, sanitized false-inheritance input and the bounded initialize probe",
    () async {
      final service = _RuntimeService(
        result: const AntigravityRuntimeSelected(
          source: AntigravityRuntimeSource.managed,
          pair: pair,
          contract: AntigravityRuntimeContract(
            version: AntigravityRelease.agentVersion,
            listsSessions: true,
            closesSessions: false,
          ),
        ),
      );
      final validator = AntigravityRuntimeVersionValidator(
        runtimeService: service,
        probeTimeout: const Duration(seconds: 7),
      );

      expect(await validator.validate(context: _context(abortSignal: StartAbortSignal.never)), isTrue);
      final call = service.call!;
      expect(call.serverPath, pair.serverPath);
      expect(call.workingDirectory, "/managed/staging/validation-cwd");
      expect(call.target, PlatformTarget.current());
      expect(call.timeout, const Duration(seconds: 7));
      expect(call.abortSignal, same(StartAbortSignal.never));
      expect(call.environment, {
        "PATH": "/usr/bin:/bin",
        "SAFE_VALUE": "retained",
        "GEMINI_HOME": "/managed/staging/validation-state",
        "AGY_ACP_FORCE_FILE_STORAGE": "1",
      });
      expect(() => call.environment["late"] = "value", throwsUnsupportedError);
    },
  );

  test("rejects an exact-contract mismatch without authenticating or creating a session", () async {
    final service = _RuntimeService(
      result: AntigravityRuntimeContractRejected(
        source: AntigravityRuntimeSource.managed,
        pair: pair,
        violations: const [AntigravityRuntimeContractViolation.agentVersion],
      ),
    );
    final logs = BufferingStdout();
    final previousLevel = Log.level;
    try {
      Log.level = LogLevel.debug;
      final valid = await IOOverrides.runZoned(
        () => AntigravityRuntimeVersionValidator(runtimeService: service).validate(
          context: _context(abortSignal: StartAbortSignal.never),
        ),
        stderr: () => logs,
      );
      expect(valid, isFalse);
    } finally {
      Log.level = previousLevel;
    }
    expect(logs.text, contains("agentVersion"));
  });

  test("retains the original initialize failure and stack in local diagnostics", () async {
    final failure = StateError("synthetic initialize failure");
    final stackTrace = StackTrace.fromString("synthetic-initialize-stack");
    final service = _RuntimeService(
      result: AntigravityRuntimeProbeFailed(
        source: AntigravityRuntimeSource.managed,
        pair: pair,
        cause: failure,
        stackTrace: stackTrace,
      ),
    );
    final logs = BufferingStdout();
    final previousLevel = Log.level;
    try {
      Log.level = LogLevel.debug;
      expect(
        await IOOverrides.runZoned(
          () => AntigravityRuntimeVersionValidator(runtimeService: service).validate(
            context: _context(abortSignal: StartAbortSignal.never),
          ),
          stderr: () => logs,
        ),
        isFalse,
      );
    } finally {
      Log.level = previousLevel;
    }
    expect(logs.text, contains("synthetic initialize failure"));
    expect(logs.text, contains("synthetic-initialize-stack"));
  });

  test("preserves abort before and after the initialize boundary", () async {
    final before = StartAbortController()..abort();
    final unused = _RuntimeService(
      result: const AntigravityRuntimeMissing(
        source: AntigravityRuntimeSource.managed,
        component: AntigravityRuntimeComponent.server,
      ),
    );
    await expectLater(
      AntigravityRuntimeVersionValidator(runtimeService: unused)
          .validate(context: _context(abortSignal: before.signal)),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(unused.call, isNull);

    final after = StartAbortController();
    final completed = _RuntimeService(
      result: const AntigravityRuntimeSelected(
        source: AntigravityRuntimeSource.managed,
        pair: pair,
        contract: AntigravityRuntimeContract(
          version: AntigravityRelease.agentVersion,
          listsSessions: true,
          closesSessions: false,
        ),
      ),
    );
    final future = AntigravityRuntimeVersionValidator(runtimeService: completed).validate(
      context: _context(abortSignal: after.signal),
    );
    after.abort();
    await expectLater(future, throwsA(isA<PluginStartAbortedException>()));
  });
}
