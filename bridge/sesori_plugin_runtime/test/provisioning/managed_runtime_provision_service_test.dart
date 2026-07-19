import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _StubManifest implements RuntimeManifest {
  const _StubManifest();

  static const RuntimeAsset _asset = RuntimeAsset(
    assetName: "opencode-test.zip",
    format: ArchiveFormat.zip,
    sha256: "abc123",
    archiveBinaryName: "opencode",
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
  SemanticVersion get minPathVersion => SemanticVersion.parse(value: "1.0.0");

  @override
  SemanticVersion get bundledVersion => SemanticVersion.parse(value: "1.17.9");

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _asset;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";

  @override
  String managedBinaryPath({required String stateDirectory}) {
    return p.join(stateDirectory, runtimeId, bundledVersion.toString(), binaryFileName);
  }
}

class _FakeValidator implements RuntimeVersionValidator {
  _FakeValidator({
    required this.pathVersion,
    required this.managedVersion,
    this.onDetect,
  });

  final SemanticVersion? pathVersion;
  final SemanticVersion? managedVersion;
  final void Function(String executable)? onDetect;
  final List<String> detectedExecutables = [];

  @override
  Future<SemanticVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    detectedExecutables.add(executable);
    onDetect?.call(executable);
    return executable == "opencode" ? pathVersion : managedVersion;
  }

  @override
  SemanticVersion? parseVersionOutput({required String output}) {
    return SemanticVersion.tryParse(value: output);
  }
}

class _FakeHost implements PluginHost {
  const _FakeHost({
    required this.stateDirectory,
    required this.abortSignal,
  });

  @override
  final String stateDirectory;

  final StartAbortSignal abortSignal;

  @override
  Map<String, String> get environment => const {};

  @override
  StartAbortSignal get startAborted => abortSignal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const stateDirectory = "/state";
  final managedBinaryPath = p.join(stateDirectory, "opencode", "1.17.9", "opencode");

  Future<List<RuntimeProvisionProgress>> resolve({
    required SemanticVersion? pathVersion,
    required SemanticVersion? managedVersion,
  }) {
    return ManagedRuntimeProvisionService(
          manifest: const _StubManifest(),
          versionValidator: _FakeValidator(pathVersion: pathVersion, managedVersion: managedVersion),
        )
        .provision(
          host: _FakeHost(
            stateDirectory: stateDirectory,
            abortSignal: StartAbortSignal.never,
          ),
        )
        .toList();
  }

  test("uses a sufficiently recent PATH runtime", () async {
    final events = await resolve(
      pathVersion: SemanticVersion.parse(value: "1.5.0"),
      managedVersion: null,
    );

    expect(events.first, isA<ProvisionResolving>());
    expect((events.last as ProvisionReady).binaryPath, "opencode");
    expect(events.whereType<ProvisionNotice>(), isEmpty);
  });

  test("uses an existing pinned managed runtime when PATH is absent", () async {
    final events = await resolve(
      pathVersion: null,
      managedVersion: SemanticVersion.parse(value: "1.17.9"),
    );

    expect((events.last as ProvisionReady).binaryPath, managedBinaryPath);
    expect(events.whereType<ProvisionNotice>(), isEmpty);
  });

  test("explains fallback from an outdated PATH runtime", () async {
    final events = await resolve(
      pathVersion: SemanticVersion.parse(value: "0.9.0"),
      managedVersion: SemanticVersion.parse(value: "1.17.9"),
    );

    expect(events.whereType<ProvisionNotice>(), hasLength(1));
    expect((events.last as ProvisionReady).binaryPath, managedBinaryPath);
  });

  test("does not accept a managed runtime with a different version", () async {
    final events = await resolve(
      pathVersion: null,
      managedVersion: SemanticVersion.parse(value: "1.0.0"),
    );

    expect(events.last, isA<ProvisionFailed>());
    expect((events.last as ProvisionFailed).message, contains("Install OpenCode locally"));
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
          versionValidator: validator,
        ).provision(
          host: _FakeHost(stateDirectory: stateDirectory, abortSignal: abort.signal),
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
          versionValidator: validator,
        ).provision(
          host: _FakeHost(stateDirectory: stateDirectory, abortSignal: abort.signal),
        );

    await expectLater(
      stream,
      emitsInOrder([isA<ProvisionResolving>(), emitsError(isA<PluginStartAbortedException>())]),
    );
    expect(validator.detectedExecutables, ["opencode"]);
  });
}
