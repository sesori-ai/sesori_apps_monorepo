import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../repositories/omp_runtime_asset_repository.dart";
import "../runtime/omp_runtime_manifest.dart";

class OmpRuntimeAssetService {
  const OmpRuntimeAssetService({
    required OmpRuntimeAssetRepository repository,
    required OmpRuntimeManifest manifest,
  }) : _repository = repository,
       _manifest = manifest;

  final OmpRuntimeAssetRepository _repository;
  final OmpRuntimeManifest _manifest;

  Future<RuntimeAsset?> resolve({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return _repository.resolveLinux(arch: target.arch);
    return Future.value(_manifest.assetFor(target: target));
  }
}
