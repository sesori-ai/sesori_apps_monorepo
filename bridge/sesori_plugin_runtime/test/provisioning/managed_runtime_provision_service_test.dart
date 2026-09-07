import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class const _StubManifest() implements RuntimeManifest {
  static const RuntimeAsset _asset = ArchiveRuntimeAsset(
    assetName: "opencode-test.zip",
    format: ArchiveFormat.zip,
    sha256: "abc123",
    archiveBinaryName: "opencode",
    layout: RuntimeArchiveLayout.singleBinary,
  );

  @override
  String get runtimeId => "opencode";

  @override
  String get displayName => "OpenCode";

  @override
  String get installDocsUrl => "https://opencode.ai/docs#install";

  @override
  String get pathExecutableName => "opencode";

  @override
  String get binaryFileName => "opencode";

  @override
  RuntimeVersion get minPathVersion => SemanticRuntimeVersion.parse(value: "1.0.0");

  @override
  RuntimeVersion get bundledVersion => SemanticRuntimeVersion.parse(value: "1.17.9");

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeVersion? parseInstalledVersion({required String value}) => parseVersion(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _asset;

  @override
  bool supportsManagedInstallOn({required PlatformTarget target}) => true;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";

  @override
  String githubReleaseAssetUrl({required String repository, required String tag, required RuntimeAsset asset}) =>
      "https://github.com/$repository/releases/download/$tag/${asset.assetName}";

  @override
  String managedBinaryPath({required String stateDirectory, required RuntimeVersion version}) {
    return p.join(stateDirectory, runtimeId, version.raw, binaryFileName);
  }
}

class _FakeValidator({
  required final RuntimeVersion? pathVersion,
  required final RuntimeVersion? managedVersion,
  final Map<String, RuntimeVersion?> candidateVersions = const {},
  final void Function(String executable)? onDetect,
}) implements RuntimeVersionValidator {
  final List<String> detectedExecutables = [];

  @override
  Future<RuntimeProbeOutcome> probe({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    final version = await detectVersion(executable: executable, environment: environment);
    return version == null
        ? RuntimeProbeMissing(
            innerError: ProcessException(executable, const []),
            stackTrace: StackTrace.empty,
          )
        : RuntimeProbeReady(version: version);
  }

  @override
  Future<RuntimeVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    detectedExecutables.add(executable);
    onDetect?.call(executable);
    if (executable == "opencode") return pathVersion;
    if (candidateVersions.containsKey(executable)) return candidateVersions[executable];
    return managedVersion;
  }

  @override
  RuntimeVersion? parseVersionOutput({required String output}) {
    return SemanticRuntimeVersion.tryParse(value: output);
  }
}

class const _FakeHost({
  @override required final String stateDirectory,
  required final StartAbortSignal abortSignal,
}) implements PluginHost {
  @override
  Map<String, String> get environment => const {};

  @override
  StartAbortSignal get startAborted => abortSignal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory stateDir;

  setUp(() async {
    stateDir = await Directory.systemTemp.createTemp("managed-provision");
  });

  tearDown(() async {
    if (stateDir.existsSync()) await stateDir.delete(recursive: true);
  });

  String managedBinaryPathFor(String version) => p.join(stateDir.path, "opencode", version, "opencode");

  void installedVersionDir(String version) {
    Directory(p.join(stateDir.path, "opencode", version)).createSync(recursive: true);
  }

  Future<List<RuntimeProvisionProgress>> resolve({
    required RuntimeVersion? pathVersion,
    required RuntimeVersion? managedVersion,
    List<String> fallbackCandidates = const [],
    Map<String, RuntimeVersion?> candidateVersions = const {},
  }) {
    return ManagedRuntimeProvisionService(
          manifest: const _StubManifest(),
          selectionService: ManagedRuntimeSelectionService(
            manifest: const _StubManifest(),
            versionValidator: _FakeValidator(
              pathVersion: pathVersion,
              managedVersion: managedVersion,
              candidateVersions: candidateVersions,
            ),
            inventory: const ManagedRuntimeInventory(manifest: _StubManifest()),
          ),
          fallbackExecutableCandidates: fallbackCandidates,
        )
        .provision(
          host: _FakeHost(
            stateDirectory: stateDir.path,
            abortSignal: StartAbortSignal.never,
          ),
          explicitExecutablePath: null,
        )
        .toList();
  }

  test("uses a sufficiently recent PATH runtime", () async {
    final events = await resolve(
      pathVersion: SemanticRuntimeVersion.parse(value: "1.5.0"),
      managedVersion: null,
    );

    expect(events.first, isA<ProvisionResolving>());
    expect((events.last as ProvisionReady).binaryPath, "opencode");
    expect(events.whereType<ProvisionNotice>(), isEmpty);
  });

  test("uses an existing pinned managed runtime when PATH is absent", () async {
    final events = await resolve(
      pathVersion: null,
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
    );

    expect((events.last as ProvisionReady).binaryPath, managedBinaryPathFor("1.17.9"));
    expect(events.whereType<ProvisionNotice>(), isEmpty);
  });

  test("explains fallback from an outdated PATH runtime", () async {
    final events = await resolve(
      pathVersion: SemanticRuntimeVersion.parse(value: "0.9.0"),
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
    );

    expect(events.whereType<ProvisionNotice>(), hasLength(1));
    expect((events.last as ProvisionReady).binaryPath, managedBinaryPathFor("1.17.9"));
  });

  test("uses a sufficiently recent fallback candidate when PATH is absent", () async {
    final events = await resolve(
      pathVersion: null,
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
      fallbackCandidates: const ["/apps/bundle/opencode", "/apps/old/opencode"],
      candidateVersions: {
        "/apps/bundle/opencode": SemanticRuntimeVersion.parse(value: "1.5.0"),
        "/apps/old/opencode": SemanticRuntimeVersion.parse(value: "1.6.0"),
      },
    );

    expect((events.last as ProvisionReady).binaryPath, "/apps/bundle/opencode");
  });

  test("skips outdated and missing fallback candidates before the managed runtime", () async {
    final events = await resolve(
      pathVersion: null,
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
      fallbackCandidates: const ["/apps/missing/opencode", "/apps/old/opencode"],
      candidateVersions: {
        "/apps/missing/opencode": null,
        "/apps/old/opencode": SemanticRuntimeVersion.parse(value: "0.9.0"),
      },
    );

    expect((events.last as ProvisionReady).binaryPath, managedBinaryPathFor("1.17.9"));
  });

  test("does not accept a managed runtime below the minimum", () async {
    final events = await resolve(
      pathVersion: null,
      managedVersion: SemanticRuntimeVersion.parse(value: "0.9.0"),
    );

    expect(events.last, isA<ProvisionFailed>());
    expect((events.last as ProvisionFailed).message, contains("Install OpenCode locally"));
  });

  test("names the selected managed version when falling back from an outdated PATH runtime", () async {
    installedVersionDir("1.5.0");
    final events = await resolve(
      pathVersion: SemanticRuntimeVersion.parse(value: "0.9.0"),
      managedVersion: SemanticRuntimeVersion.parse(value: "1.5.0"),
      candidateVersions: {managedBinaryPathFor("1.17.9"): null},
    );

    expect((events.last as ProvisionReady).binaryPath, managedBinaryPathFor("1.5.0"));
    final notice = events.whereType<ProvisionNotice>().single;
    expect(notice.message, contains("managed OpenCode 1.5.0"));
    expect(notice.message, isNot(contains("1.17.9")));
  });

  test("never installs when no existing runtime is usable", () async {
    final events = await resolve(pathVersion: null, managedVersion: null);

    expect(events.last, isA<ProvisionFailed>());
    expect(events.whereType<ProvisionDownloading>(), isEmpty);
    expect(events.whereType<ProvisionExtracting>(), isEmpty);
  });

  test("does not probe when resolution was already aborted", () async {
    final abort = StartAbortController()..abort();
    final validator = _FakeValidator(pathVersion: null, managedVersion: null);
    final stream =
        ManagedRuntimeProvisionService(
          manifest: const _StubManifest(),
          selectionService: ManagedRuntimeSelectionService(
            manifest: const _StubManifest(),
            versionValidator: validator,
            inventory: const ManagedRuntimeInventory(manifest: _StubManifest()),
          ),
          fallbackExecutableCandidates: const [],
        ).provision(
          host: _FakeHost(stateDirectory: stateDir.path, abortSignal: abort.signal),
          explicitExecutablePath: null,
        );

    await expectLater(stream, emitsError(isA<PluginStartAbortedException>()));
    expect(validator.detectedExecutables, isEmpty);
  });

  test("stops before the managed probe when aborted after the PATH probe", () async {
    final abort = StartAbortController();
    final validator = _FakeValidator(
      pathVersion: null,
      managedVersion: null,
      onDetect: (executable) {
        if (executable == "opencode") abort.abort();
      },
    );
    final stream =
        ManagedRuntimeProvisionService(
          manifest: const _StubManifest(),
          selectionService: ManagedRuntimeSelectionService(
            manifest: const _StubManifest(),
            versionValidator: validator,
            inventory: const ManagedRuntimeInventory(manifest: _StubManifest()),
          ),
          fallbackExecutableCandidates: const [],
        ).provision(
          host: _FakeHost(stateDirectory: stateDir.path, abortSignal: abort.signal),
          explicitExecutablePath: null,
        );

    await expectLater(
      stream,
      emitsInOrder([isA<ProvisionResolving>(), emitsError(isA<PluginStartAbortedException>())]),
    );
    expect(validator.detectedExecutables, ["opencode"]);
  });
}
