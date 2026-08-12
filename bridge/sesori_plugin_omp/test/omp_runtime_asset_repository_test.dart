import "dart:io";

import "package:omp_plugin/src/api/omp_linux_libc_probe_api.dart";
import "package:omp_plugin/src/repositories/omp_runtime_asset_repository.dart";
import "package:omp_plugin/src/runtime/omp_runtime_manifest.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

class _Executor implements CommandExecutor {
  _Executor({required this.result});

  final CommandResult result;
  String? executable;
  List<String>? arguments;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    return result;
  }
}

void main() {
  Future<String> resolve({required String stdout, required String stderr}) async {
    final executor = _Executor(
      result: CommandResult(exitCode: 0, stdout: stdout, stderr: stderr),
    );
    final repository = OmpRuntimeAssetRepository(
      api: OmpLinuxLibcProbeApi(
        commandExecutor: executor,
        alpineMarkerPath: "/path/that/does/not/exist",
        timeout: const Duration(seconds: 1),
      ),
      manifest: const OmpRuntimeManifest(),
    );
    final asset = await repository.resolveLinux(arch: PlatformArch.x64);
    expect(executor.executable, "ldd");
    expect(executor.arguments, ["--version"]);
    return asset!.assetName;
  }

  test("selects musl from the Alpine marker without invoking ldd", () async {
    final marker = File("${Directory.systemTemp.path}/omp-alpine-${DateTime.now().microsecondsSinceEpoch}")
      ..writeAsStringSync("3.22");
    final executor = _Executor(
      result: const CommandResult(exitCode: 1, stdout: "", stderr: "unavailable"),
    );
    try {
      final repository = OmpRuntimeAssetRepository(
        api: OmpLinuxLibcProbeApi(
          commandExecutor: executor,
          alpineMarkerPath: marker.path,
          timeout: const Duration(seconds: 1),
        ),
        manifest: const OmpRuntimeManifest(),
      );
      final asset = await repository.resolveLinux(arch: PlatformArch.arm64);
      expect(asset!.assetName, "omp-linux-musl-arm64");
      expect(executor.executable, isNull);
    } finally {
      marker.deleteSync();
    }
  });

  test("selects glibc from ldd evidence", () async {
    expect(await resolve(stdout: "ldd (GNU libc) 2.39", stderr: ""), "omp-linux-x64");
  });

  test("selects musl from stdout or stderr evidence", () async {
    expect(await resolve(stdout: "", stderr: "musl libc (x86_64)"), "omp-linux-musl-x64");
  });

  test("fails when ldd evidence identifies no libc", () async {
    expect(
      () => resolve(stdout: "unknown loader", stderr: ""),
      throwsA(isA<StateError>()),
    );
  });
}
