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
  late Directory stateDir;
  RuntimeVersion version(String value) => SemanticRuntimeVersion.parse(value: value);

  setUp(() async {
    stateDir = await Directory.systemTemp.createTemp("managed-selection");
  });

  tearDown(() async {
    if (stateDir.existsSync()) await stateDir.delete(recursive: true);
  });

  /// Creates the on-disk version directory the inventory reports; the probe
  /// outcome for its binary still decides whether the candidate is selected.
  String installed(String value) {
    Directory(p.join(stateDir.path, "runtime", value)).createSync(recursive: true);
    return p.join(stateDir.path, "runtime", value, "runtime");
  }

  String managedPathFor(String value) => p.join(stateDir.path, "runtime", value, "runtime");

  Future<ManagedRuntimeSelection> select({
    required _Validator validator,
    String? explicitExecutablePath,
    List<String> fallbackExecutableCandidates = const [],
    required StartAbortSignal abortSignal,
  }) {
    return ManagedRuntimeSelectionService(
      manifest: manifest,
      versionValidator: validator,
      inventory: const ManagedRuntimeInventory(manifest: manifest),
    ).select(
      explicitExecutablePath: explicitExecutablePath,
      fallbackExecutableCandidates: fallbackExecutableCandidates,
      environment: const {"PATH": "/bin"},
      stateDirectory: stateDir.path,
      abortSignal: abortSignal,
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
        managedPathFor("2.0.0"): RuntimeProbeReady(version: version("2.0.0")),
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

  test("accepts any managed version at or above the minimum", () async {
    final validator = _Validator(
      outcomes: {
        managedPathFor("2.0.0"): RuntimeProbeReady(version: version("2.1.0")),
      },
      onProbe: null,
    );

    final result = await select(validator: validator, abortSignal: StartAbortSignal.never);

    expect(result, isA<ManagedRuntimeManagedSelected>());
    expect((result as ManagedRuntimeSelected).version.raw, "2.1.0");
  });

  test("prefers the pinned managed version over a newer installed one", () async {
    installed("1.5.0");
    installed("2.0.0");
    final validator = _Validator(
      outcomes: {
        managedPathFor("2.0.0"): RuntimeProbeReady(version: version("2.0.0")),
        managedPathFor("1.5.0"): RuntimeProbeReady(version: version("1.5.0")),
      },
      onProbe: null,
    );

    final result = await select(validator: validator, abortSignal: StartAbortSignal.never);

    expect((result as ManagedRuntimeSelected).binaryPath, managedPathFor("2.0.0"));
    expect(validator.probes, isNot(contains(managedPathFor("1.5.0"))));
  });

  test("falls back to the highest supported version when the pinned one is absent", () async {
    installed("1.0.0");
    installed("1.5.0");
    final validator = _Validator(
      outcomes: {
        managedPathFor("1.5.0"): RuntimeProbeReady(version: version("1.5.0")),
        managedPathFor("1.0.0"): RuntimeProbeReady(version: version("1.0.0")),
      },
      onProbe: null,
    );

    final result = await select(validator: validator, abortSignal: StartAbortSignal.never);

    final selected = result as ManagedRuntimeManagedSelected;
    expect(selected.binaryPath, managedPathFor("1.5.0"));
    expect(selected.version.raw, "1.5.0");
    expect(validator.probes, isNot(contains(managedPathFor("1.0.0"))));
  });

  test("accepts an installed version equal to the minimum", () async {
    installed("1.0.0");
    final validator = _Validator(
      outcomes: {
        managedPathFor("1.0.0"): RuntimeProbeReady(version: version("1.0.0")),
      },
      onProbe: null,
    );

    final result = await select(validator: validator, abortSignal: StartAbortSignal.never);

    expect((result as ManagedRuntimeSelected).version.raw, "1.0.0");
  });

  test("skips an unrunnable superseded version and takes the next one down", () async {
    installed("1.9.0");
    installed("1.5.0");
    final validator = _Validator(
      outcomes: {
        managedPathFor("1.9.0"): const RuntimeProbeNonZeroExit(exitCode: 1),
        managedPathFor("1.5.0"): RuntimeProbeReady(version: version("1.5.0")),
      },
      onProbe: null,
    );

    final result = await select(validator: validator, abortSignal: StartAbortSignal.never);

    expect((result as ManagedRuntimeSelected).binaryPath, managedPathFor("1.5.0"));
  });

  test("never probes a below-minimum or unparseable managed directory", () async {
    installed("0.9.0");
    installed(".sesori-runtime-staging");
    final validator = _Validator(
      outcomes: {
        managedPathFor("0.9.0"): RuntimeProbeReady(version: version("0.9.0")),
      },
      onProbe: null,
    );

    final result = await select(validator: validator, abortSignal: StartAbortSignal.never);

    expect(result, isA<ManagedRuntimeNotSelected>());
    expect(validator.probes, ["runtime", managedPathFor("2.0.0")]);
  });

  test("prefers an informative superseded rejection over a missing pinned one", () async {
    installed("1.5.0");
    const supersededFailure = RuntimeProbeUnrecognized();
    final result = await select(
      validator: _Validator(
        outcomes: {
          managedPathFor("1.5.0"): supersededFailure,
        },
        onProbe: null,
      ),
      abortSignal: StartAbortSignal.never,
    );

    final automatic = result as ManagedRuntimeAutomaticNotSelected;
    expect((automatic.managedRejection as ManagedRuntimeProbeRejected).outcome, same(supersededFailure));
  });

  test("preserves PATH and managed rejection details", () async {
    const pathFailure = RuntimeProbeNonZeroExit(exitCode: 7);
    const managedFailure = RuntimeProbeUnrecognized();
    final result = await select(
      validator: _Validator(
        outcomes: {
          "runtime": pathFailure,
          managedPathFor("2.0.0"): managedFailure,
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
