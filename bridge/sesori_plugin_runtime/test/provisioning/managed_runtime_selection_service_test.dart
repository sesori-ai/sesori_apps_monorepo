import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class const _Manifest() extends RuntimeManifest {
  @override
  String get runtimeId => "runtime";

  @override
  String get displayName => "Runtime";

  @override
  String get installDocsUrl => "https://example.test";

  @override
  String get pathExecutableName => "runtime";

  @override
  String get binaryFileName => "runtime";

  @override
  RuntimeVersion get minPathVersion => SemanticRuntimeVersion.parse(value: "1.0.0");

  @override
  RuntimeVersion get bundledVersion => SemanticRuntimeVersion.parse(value: "2.0.0");

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => null;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";
}

class _Validator({
  required final Map<String, RuntimeProbeOutcome> outcomes,
  required final void Function(String executable)? onProbe,
}) implements RuntimeVersionValidator {
  final List<String> probes = [];

  @override
  Future<RuntimeProbeOutcome> probe({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    probes.add(executable);
    onProbe?.call(executable);
    return outcomes[executable] ??
        RuntimeProbeMissing(
          innerError: ProcessException(executable, const []),
          stackTrace: StackTrace.empty,
        );
  }

  @override
  Future<RuntimeVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    return switch (await probe(executable: executable, environment: environment)) {
      RuntimeProbeReady(:final version) => version,
      RuntimeProbeFailure() => null,
    };
  }

  @override
  RuntimeVersion? parseVersionOutput({required String output}) => SemanticRuntimeVersion.tryParse(value: output);
}

void main() {
  const manifest = _Manifest();
  const stateDirectory = "/state";
  final managedPath = p.join(stateDirectory, "runtime", "2.0.0", "runtime");
  RuntimeVersion version(String value) => SemanticRuntimeVersion.parse(value: value);

  Future<ManagedRuntimeSelection> select({
    required _Validator validator,
    String? explicitExecutablePath,
    List<String> fallbackExecutableCandidates = const [],
    ManagedRuntimeVersionPolicy managedVersionPolicy = ManagedRuntimeVersionPolicy.exact,
    required StartAbortSignal abortSignal,
  }) {
    return ManagedRuntimeSelectionService(
      manifest: manifest,
      versionValidator: validator,
    ).select(
      explicitExecutablePath: explicitExecutablePath,
      fallbackExecutableCandidates: fallbackExecutableCandidates,
      environment: const {"PATH": "/bin"},
      stateDirectory: stateDirectory,
      abortSignal: abortSignal,
      managedVersionPolicy: managedVersionPolicy,
    );
  }

  test("an explicit runtime is authoritative", () async {
    final validator = _Validator(
      outcomes: {
        "/custom/runtime": RuntimeProbeReady(version: version("1.5.0")),
        "runtime": RuntimeProbeReady(version: version("3.0.0")),
      },
      onProbe: null,
    );

    final result = await select(
      validator: validator,
      explicitExecutablePath: "/custom/runtime",
      fallbackExecutableCandidates: const ["/desktop/runtime"],
      abortSignal: StartAbortSignal.never,
    );

    expect(result, isA<ManagedRuntimeSelected>());
    expect(result, isA<ManagedRuntimeExplicitSelected>());
    expect((result as ManagedRuntimeSelected).binaryPath, "/custom/runtime");
    expect(validator.probes, ["/custom/runtime"]);
  });

  test("selects PATH, fallback, then managed in order", () async {
    final validator = _Validator(
      outcomes: {
        "runtime": RuntimeProbeReady(version: version("0.9.0")),
        "/old/runtime": RuntimeProbeReady(version: version("0.8.0")),
        "/desktop/runtime": RuntimeProbeReady(version: version("1.5.0")),
        managedPath: RuntimeProbeReady(version: version("2.0.0")),
      },
      onProbe: null,
    );

    final result = await select(
      validator: validator,
      fallbackExecutableCandidates: const ["/old/runtime", "/desktop/runtime"],
      abortSignal: StartAbortSignal.never,
    );

    expect(result, isA<ManagedRuntimeSelected>());
    final selected = result as ManagedRuntimeSelected;
    expect(selected, isA<ManagedRuntimeFallbackSelected>());
    expect(selected.binaryPath, "/desktop/runtime");
    expect((selected as ManagedRuntimeFallbackSelected).rejectedPathVersion?.raw, "0.9.0");
    expect(validator.probes, ["runtime", "/old/runtime", "/desktop/runtime"]);
  });

  test("applies exact or minimum policy to the managed runtime", () async {
    _Validator validator() => _Validator(
      outcomes: {
        managedPath: RuntimeProbeReady(version: version("2.1.0")),
      },
      onProbe: null,
    );

    final exact = await select(validator: validator(), abortSignal: StartAbortSignal.never);
    expect(exact, isA<ManagedRuntimeNotSelected>());

    final minimum = await select(
      validator: validator(),
      managedVersionPolicy: ManagedRuntimeVersionPolicy.minimum,
      abortSignal: StartAbortSignal.never,
    );
    expect(minimum, isA<ManagedRuntimeSelected>());
    expect(minimum, isA<ManagedRuntimeManagedSelected>());
    final selected = minimum as ManagedRuntimeSelected;
    expect(selected.version.raw, "2.1.0");
  });

  test("preserves PATH and managed rejection details", () async {
    const pathFailure = RuntimeProbeNonZeroExit(exitCode: 7);
    const managedFailure = RuntimeProbeUnrecognized();
    final result = await select(
      validator: _Validator(
        outcomes: {
          "runtime": pathFailure,
          managedPath: managedFailure,
        },
        onProbe: null,
      ),
      abortSignal: StartAbortSignal.never,
    );

    final notSelected = result as ManagedRuntimeNotSelected;
    expect((notSelected.primaryRejection as ManagedRuntimeProbeRejected).outcome, same(pathFailure));
    final automatic = notSelected as ManagedRuntimeAutomaticNotSelected;
    expect((automatic.managedRejection as ManagedRuntimeProbeRejected).outcome, same(managedFailure));
  });

  test("uses a failed fallback probe as the primary rejection", () async {
    final pathFailure = RuntimeProbeMissing(
      innerError: const ProcessException("runtime", ["--version"]),
      stackTrace: StackTrace.empty,
    );
    const fallbackFailure = RuntimeProbeNonZeroExit(exitCode: 7);
    final result = await select(
      validator: _Validator(
        outcomes: {
          "runtime": pathFailure,
          "/desktop/runtime": fallbackFailure,
        },
        onProbe: null,
      ),
      fallbackExecutableCandidates: const ["/desktop/runtime"],
      abortSignal: StartAbortSignal.never,
    );

    final notSelected = result as ManagedRuntimeNotSelected;
    expect((notSelected.primaryRejection as ManagedRuntimeProbeRejected).outcome, same(fallbackFailure));
  });

  test("keeps an informative PATH rejection when fallbacks are missing", () async {
    const pathFailure = RuntimeProbeNonZeroExit(exitCode: 7);
    final fallbackFailure = RuntimeProbeMissing(
      innerError: const ProcessException("/desktop/runtime", ["--version"]),
      stackTrace: StackTrace.empty,
    );
    final result = await select(
      validator: _Validator(
        outcomes: {
          "runtime": pathFailure,
          "/desktop/runtime": fallbackFailure,
        },
        onProbe: null,
      ),
      fallbackExecutableCandidates: const ["/desktop/runtime"],
      abortSignal: StartAbortSignal.never,
    );

    final notSelected = result as ManagedRuntimeNotSelected;
    expect((notSelected.primaryRejection as ManagedRuntimeProbeRejected).outcome, same(pathFailure));
  });

  test("throws before probing when already aborted", () async {
    final abort = StartAbortController()..abort();
    final validator = _Validator(outcomes: const {}, onProbe: null);

    await expectLater(
      select(validator: validator, abortSignal: abort.signal),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(validator.probes, isEmpty);
  });

  test("stops selection when aborted after a completed probe", () async {
    final abort = StartAbortController();
    final validator = _Validator(
      outcomes: {
        "runtime": RuntimeProbeMissing(
          innerError: const ProcessException("runtime", ["--version"]),
          stackTrace: StackTrace.empty,
        ),
      },
      onProbe: (_) => abort.abort(),
    );

    await expectLater(
      select(validator: validator, abortSignal: abort.signal),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(validator.probes, ["runtime"]);
  });
}
