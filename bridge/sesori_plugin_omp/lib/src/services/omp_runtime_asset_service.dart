import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../repositories/omp_runtime_asset_repository.dart";
import "../runtime/omp_runtime_manifest.dart";

class const OmpRuntimeAssetService({
  required final OmpRuntimeAssetRepository _repository,
  required final OmpRuntimeManifest _manifest,
}) {
  Future<RuntimeAsset?> resolve({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return _repository.resolveLinux(arch: target.arch);
    return Future.value(_manifest.assetFor(target: target));
  }
}
