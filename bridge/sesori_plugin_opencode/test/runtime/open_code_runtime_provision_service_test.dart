import "package:opencode_plugin/src/runtime/open_code_runtime_cleaner.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_install_service.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_manifest.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_provision_service.dart";
import "package:opencode_plugin/src/runtime/open_code_version_validator.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _FakeValidator implements OpenCodeVersionValidator {
  _FakeValidator({this.osVersion, this.managedVersion});

  /// Version reported for the PATH `opencode`.
  final SemanticVersion? osVersion;

  /// Version reported when probing a managed (absolute-path) binary — the
  /// cached-runtime runnability check.
  final SemanticVersion? managedVersion;

  @override
  Future<SemanticVersion?> detectVersion({required String executable, required Map<String, String>? environment}) async {
    return executable == "opencode" ? osVersion : managedVersion;
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
    SemanticVersion? managedVersion,
    _FakeInstallService? install,
    _FakeCleaner? cleaner,
  }) {
    return OpenCodeRuntimeProvisionService(
      manifest: const OpenCodeRuntimeManifest(),
      versionValidator: _FakeValidator(osVersion: osVersion, managedVersion: managedVersion),
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
    final events = await run(build(osVersion: SemanticVersion.parse(value: "0.9.0"), install: install));

    expect(events.whereType<ProvisionNotice>(), isNotEmpty);
    expect(events.whereType<ProvisionDownloading>(), isNotEmpty);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
    expect(install.installCalled, isTrue);
  });

    test("reuses an already-installed, runnable managed runtime without a notice when PATH OpenCode is absent", () async {
      final install = _FakeInstallService(installed: true);
      final events = await run(build(install: install, managedVersion: SemanticVersion.parse(value: "1.17.9")));

      expect(events.whereType<ProvisionNotice>(), isEmpty);
      expect(events.last, isA<ProvisionReady>());
      expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
      expect(install.installCalled, isFalse);
    });

    test("reinstalls when the cached managed runtime is present but not runnable", () async {
      // isInstalled true (sentinel matches) but the binary does not run.
      final install = _FakeInstallService(installed: true, installEvents: const [ProvisionExtracting()]);
      final events = await run(build(install: install));

      expect(install.installCalled, isTrue);
      expect(events.last, isA<ProvisionReady>());
      expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
    });

  test("downloads the managed runtime when absent and not yet installed", () async {
    final install = _FakeInstallService(installEvents: const [ProvisionExtracting()]);
    final events = await run(build(install: install));

    expect(install.installCalled, isTrue);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, equals(managedBinaryPath));
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
