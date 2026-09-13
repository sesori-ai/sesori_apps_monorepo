import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
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
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test";
}

class _Validator({required final RuntimeProbeOutcome outcome}) implements RuntimeVersionValidator {
  int probeCount = 0;

  @override
  Future<RuntimeProbeOutcome> probe({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    probeCount++;
    return outcome;
  }

  @override
  Future<bool> validate({required RuntimeCandidateValidationContext context}) async => false;

  @override
  Future<RuntimeVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async => null;

  @override
  RuntimeVersion? parseVersionOutput({required String output}) => null;
}

void main() {
  const manifest = _Manifest();
  late Directory stateDirectory;

  setUp(() async {
    stateDirectory = await Directory.systemTemp.createTemp("managed-runtime-upgrade");
  });

  tearDown(() async {
    if (stateDirectory.existsSync()) await stateDirectory.delete(recursive: true);
  });

  ManagedRuntimeUpgradeService service(_Validator validator) => ManagedRuntimeUpgradeService(
    pathAuthority: RuntimeVersionManagedRuntimePathAuthority(
      manifest: manifest,
      versionValidator: validator,
    ),
    inventory: const ManagedRuntimeInventory(manifest: manifest),
  );

  void addSupersededInstall() {
    Directory(p.join(stateDirectory.path, "runtime", "1.5.0")).createSync(recursive: true);
  }

  test("declines without a superseded managed install and skips PATH", () async {
    final validator = _Validator(
      outcome: RuntimeProbeReady(version: SemanticRuntimeVersion.parse(value: "1.5.0")),
    );

    expect(
      await service(validator).shouldUpgrade(environment: const {}, stateDirectory: stateDirectory.path),
      isFalse,
    );
    expect(validator.probeCount, 0);
  });

  test("declines whenever PATH answers, including below the minimum", () async {
    addSupersededInstall();
    final validator = _Validator(
      outcome: RuntimeProbeReady(version: SemanticRuntimeVersion.parse(value: "0.9.0")),
    );

    expect(
      await service(validator).shouldUpgrade(environment: const {}, stateDirectory: stateDirectory.path),
      isFalse,
    );
  });

  test("upgrades only when PATH is genuinely absent", () async {
    addSupersededInstall();
    final validator = _Validator(
      outcome: RuntimeProbeMissing(
        innerError: const ProcessException("runtime", ["--version"], "missing", 2),
        stackTrace: StackTrace.empty,
      ),
    );

    expect(
      await service(validator).shouldUpgrade(environment: const {}, stateDirectory: stateDirectory.path),
      isTrue,
    );
  });

  test("declines when the PATH probe fails ambiguously", () async {
    addSupersededInstall();
    final validator = _Validator(outcome: const RuntimeProbeNonZeroExit(exitCode: 1));

    expect(
      await service(validator).shouldUpgrade(environment: const {}, stateDirectory: stateDirectory.path),
      isFalse,
    );
  });
}
