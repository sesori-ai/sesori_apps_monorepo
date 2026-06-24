import "package:opencode_plugin/src/runtime/open_code_runtime_cleaner.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_install_service.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_manifest.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_provision_service.dart";
import "package:opencode_plugin/src/runtime/open_code_version_validator.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _FakeValidator implements OpenCodeVersionValidator {
  _FakeValidator({this.osVersion, List<SemanticVersion?>? managedVersions})
    : _managedVersions = managedVersions ?? const [];

  /// Version reported for the PATH `opencode`.
  final SemanticVersion? osVersion;

  /// Versions reported, in order, when probing a managed (absolute-path) binary:
  /// the cached-runtime check, then the post-install check. Beyond the list,
  /// `null` (not runnable).
  final List<SemanticVersion?> _managedVersions;
  int _managedCalls = 0;

  @override
  Future<SemanticVersion?> detectVersion({required String executable, required Map<String, String>? environment}) async {
    if (executable == "opencode") {
      return osVersion;
    }
    final index = _managedCalls++;
    return index < _managedVersions.length ? _managedVersions[index] : null;
  }
}

class _FakeInstallService implements OpenCodeRuntimeInstallService {
  _FakeInstallService({this.installed = false, this.installError, this.installEvents = const []});

  final bool installed;
  final Object? installError;
  final List<RuntimeProvisionProgress> installEvents;
  bool installCalled = false;

  @override
  bool isInstalled({required String versionDir, required String binaryFileName, required String sha256}) => installed;

  @override
  Stream<RuntimeProvisionProgress> install({
    required String managedDir,
    required String versionDir,
    required String binaryFileName,
    required String downloadUrl,
    required OpenCodeRuntimeAsset asset,
    required StartAbortSignal startAborted,
  }) async* {
    installCalled = true;
    final err = installError;
    if (err != null) {
      throw err;
    }
    for (final event in installEvents) {
      yield event;
    }
  }
}

class _FakeCleaner implements OpenCodeRuntimeCleaner {
  String? sweptManagedDir;
  String? sweptKeepVersion;

  @override
  Future<void> sweep({required String managedDir, required String keepVersion}) async {
    sweptManagedDir = managedDir;
    sweptKeepVersion = keepVersion;
  }
}

class _FakeHost implements PluginHost {
  _FakeHost({required this.stateDirectory, StartAbortSignal? startAborted})
    : startAborted = startAborted ?? StartAbortSignal.never;

  @override
  final String stateDirectory;
  @override
  final Map<String, String> environment = const {};
  @override
  final StartAbortSignal startAborted;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const stateDir = "/state";
  final String managedBinaryPath = p.join(stateDir, "opencode", "1.17.9", "opencode");

  OpenCodeRuntimeProvisionService build({
    SemanticVersion? osVersion,
    List<SemanticVersion?>? managedVersions,
    _FakeInstallService? install,
    _FakeCleaner? cleaner,
  }) {
    return OpenCodeRuntimeProvisionService(
      manifest: const OpenCodeRuntimeManifest(),
      versionValidator: _FakeValidator(osVersion: osVersion, managedVersions: managedVersions),
      installService: install ?? _FakeInstallService(),
      cleaner: cleaner ?? _FakeCleaner(),
    );
  }

  Future<List<RuntimeProvisionProgress>> run(OpenCodeRuntimeProvisionService service) {
    return service.provision(host: _FakeHost(stateDirectory: stateDir)).toList();
  }

  test("uses PATH OpenCode as-is when it meets the minimum version", () async {
    final install = _FakeInstallService();
    final cleaner = _FakeCleaner();
    final events = await run(build(osVersion: SemanticVersion.parse(value: "1.5.0"), install: install, cleaner: cleaner));

    expect(events.first, isA<ProvisionResolving>());
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals("opencode"));
    expect(events.whereType<ProvisionNotice>(), isEmpty);
    expect(install.installCalled, isFalse);
    // Superseded managed versions are still swept, keeping the bundled one.
    expect(cleaner.sweptKeepVersion, equals("1.17.9"));
  });

  test("falls back to the managed runtime with a notice when PATH OpenCode is too old", () async {
    final install = _FakeInstallService(installEvents: const [ProvisionDownloading(receivedBytes: 1, totalBytes: 2)]);
    final events = await run(
      build(
        osVersion: SemanticVersion.parse(value: "0.9.0"),
        install: install,
        managedVersions: [SemanticVersion.parse(value: "1.17.9")], // post-install probe
      ),
    );

    expect(events.whereType<ProvisionNotice>(), isNotEmpty);
    expect(events.whereType<ProvisionDownloading>(), isNotEmpty);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
    expect(install.installCalled, isTrue);
  });

  test("reuses an already-installed, runnable managed runtime without a notice when PATH OpenCode is absent", () async {
    final install = _FakeInstallService(installed: true);
    final events = await run(build(install: install, managedVersions: [SemanticVersion.parse(value: "1.17.9")]));

    expect(events.whereType<ProvisionNotice>(), isEmpty);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
    expect(install.installCalled, isFalse);
  });

  test("reinstalls when the cached managed runtime is present but not runnable", () async {
    // isInstalled true (sentinel matches) but the cached binary does not run;
    // after reinstall the freshly-placed binary reports the bundled version.
    final install = _FakeInstallService(installed: true, installEvents: const [ProvisionExtracting()]);
    final events = await run(build(install: install, managedVersions: [null, SemanticVersion.parse(value: "1.17.9")]));

    expect(install.installCalled, isTrue);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
  });

  test("reinstalls when the cached managed runtime runs but reports the wrong version", () async {
    final install = _FakeInstallService(installed: true, installEvents: const [ProvisionExtracting()]);
    // Cached probe: runnable but wrong version -> reinstall; post-install: correct.
    final events = await run(
      build(
        install: install,
        managedVersions: [SemanticVersion.parse(value: "1.0.0"), SemanticVersion.parse(value: "1.17.9")],
      ),
    );

    expect(install.installCalled, isTrue);
    expect(events.last, isA<ProvisionReady>());
  });

  test("downloads the managed runtime when absent and not yet installed", () async {
    final install = _FakeInstallService(installEvents: const [ProvisionExtracting()]);
    final events = await run(build(install: install, managedVersions: [SemanticVersion.parse(value: "1.17.9")]));

    expect(install.installCalled, isTrue);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
  });

  test("reports a non-fatal failure when a freshly-installed runtime is not runnable", () async {
    // Install succeeds but the placed binary does not run on this host.
    final install = _FakeInstallService(installEvents: const [ProvisionExtracting()]);
    final events = await run(build(install: install, managedVersions: const [null]));

    expect(install.installCalled, isTrue);
    expect(events.last, isA<ProvisionFailed>());
    expect((events.last as ProvisionFailed).message, contains("not runnable"));
  });

  test("reports a non-fatal failure when the managed install fails", () async {
    final install = _FakeInstallService(installError: const OpenCodeRuntimeInstallException("network down"));
    final events = await run(build(install: install));

    expect(events.last, isA<ProvisionFailed>());
    expect((events.last as ProvisionFailed).message, contains("network down"));
  });

  test("propagates an aborted install as a start-abort", () async {
    final install = _FakeInstallService(installError: const PluginStartAbortedException());
    await expectLater(
      run(build(install: install)),
      throwsA(isA<PluginStartAbortedException>()),
    );
  });
}
