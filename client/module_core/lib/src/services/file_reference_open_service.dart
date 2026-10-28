import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../foundation/models/file_reference/file_reference.dart";
import "../foundation/platform/active_bridge_locality.dart";
import "../logging/logging.dart";
import "../platform/url_launcher.dart";
import "models/file_reference_open_outcome.dart";

/// Opens a file reference in this computer's default app when the connected
/// bridge runs here, and otherwise asks for the in-app preview.
@lazySingleton
class FileReferenceOpenService({
  required final ConnectionService _connectionService,
  required final ActiveBridgeLocality _locality,
  required final UrlLauncher _urlLauncher,
}) {
  Future<FileReferenceOpenOutcome> open({required FileReference reference}) async {
    final bridgeId = _connectionService.activeConfig?.bridgeId;
    if (bridgeId == null || !_locality.isLocalBridge(bridgeId: bridgeId)) return const FileReferenceNeedsPreview();
    final uri = Uri.file(reference.absolutePath);
    try {
      if (await _urlLauncher.launch(uri, mode: UrlLaunchMode.externalApp)) return const FileReferenceOpenedLocally();
      logw("No default app opened ${reference.absolutePath}; showing the preview");
    } on Object catch (error, stackTrace) {
      logw("Opening ${reference.absolutePath} in its default app failed; showing the preview", error, stackTrace);
    }
    return const FileReferenceNeedsPreview();
  }
}
