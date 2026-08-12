import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../api/omp_linux_libc_probe_api.dart";
import "../models/omp_linux_libc.dart";
import "../runtime/omp_runtime_manifest.dart";

class OmpRuntimeAssetRepository {
  const OmpRuntimeAssetRepository({
    required OmpLinuxLibcProbeApi api,
    required OmpRuntimeManifest manifest,
  }) : _api = api,
       _manifest = manifest;

  final OmpLinuxLibcProbeApi _api;
  final OmpRuntimeManifest _manifest;

  Future<RuntimeAsset?> resolveLinux({required PlatformArch arch}) async {
    final evidence = await _api.probe();
    final libc = switch (evidence) {
      OmpAlpineMarkerEvidence() => OmpLinuxLibc.musl,
      OmpLddEvidence(:final result) => _libcFromLdd(result),
    };
    return _manifest.assetForLinux(arch: arch, libc: libc);
  }

  OmpLinuxLibc _libcFromLdd(CommandResult result) {
    final output = "${result.stdout}\n${result.stderr}".toLowerCase();
    if (output.contains("musl")) return OmpLinuxLibc.musl;
    if (output.contains("glibc") || output.contains("gnu libc")) return OmpLinuxLibc.glibc;
    throw StateError("Could not determine Linux libc from ldd");
  }
}
