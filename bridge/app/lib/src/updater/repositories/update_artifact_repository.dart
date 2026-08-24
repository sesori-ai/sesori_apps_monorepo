import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../api/checksum_manifest_api.dart';
import '../foundation/update_policy.dart';
import '../models/release_info.dart';
import '../models/update_result.dart';

/// Acquires and verifies a bridge release archive, mapping the neutral outcomes
/// of the shared runtime primitives ([BinaryDownloadClient], [ChecksumValidator],
/// [ArchiveExtractor]) into the updater's [UpdateResult] vocabulary. The mapping
/// boundary lives here so the primitives stay reusable by other consumers.
///
/// Byte progress from the download is forwarded to the injected [_progressSink]
/// so a presentation layer can render it; the repository itself performs no
/// terminal output. Composition wires a sink backed by a rendering listener
/// (the explicit `update` command) or a no-listener drain (the background
/// updater).
class UpdateArtifactRepository({
  required final BinaryDownloadClient _downloadClient,
  required final ChecksumManifestApi _checksumManifestApi,
  required final ChecksumValidator _checksumValidator,
  required final ArchiveExtractor _archiveExtractor,
  required final ArchiveFormat _archiveFormat,
  required final StreamSink<DownloadProgress> _progressSink,
}) {
  Future<UpdateResult?> downloadArchive({
    required ReleaseInfo release,
    required String archivePath,
  }) async {
    try {
      // Forward each byte-progress event to the injected sink (a rendering
      // listener, or a no-listener drain). `forEach` completes with the stream's
      // error, so a thrown `DownloadException` is still caught and mapped below;
      // a connection-phase error (e.g. SocketException from the initial send)
      // propagates raw and is classified by the install service, as before.
      await _downloadClient.download(url: release.assetUrl, destinationPath: archivePath).forEach(_progressSink.add);
      return null;
    } on DownloadException catch (error) {
      switch (error.kind) {
        case DownloadFailureKind.network:
          return UpdateResult.networkError;
        case DownloadFailureKind.failed:
          return UpdateResult.downloadFailed;
      }
    }
  }

  Future<bool> verifyDownloadedArchive({
    required ReleaseInfo release,
    required String archivePath,
  }) async {
    try {
      final manifest = await _checksumManifestApi.fetchManifest(url: release.checksumsUrl);
      if (manifest == null) {
        return false;
      }

      final String? expectedChecksum = manifest.checksumForFileName(
        fileName: _publishedAssetFileName(assetUrl: release.assetUrl),
      );
      if (expectedChecksum == null) {
        return false;
      }

      return await _checksumValidator.verify(
        filePath: archivePath,
        expectedHash: expectedChecksum,
      );
    } on Object catch (error, stackTrace) {
      if (isTransientNetworkError(error)) {
        rethrow;
      }
      Log.w(
        'verifyDownloadedArchive: unexpected error, failing checksum verification: $error',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> extractArchive({
    required String archivePath,
    required String stagingPath,
  }) async {
    final ArchiveExtractionResult result = await _archiveExtractor.extract(
      archivePath: archivePath,
      stagingPath: stagingPath,
      format: _archiveFormat,
    );
    if (!result.succeeded) {
      // The caller maps a false result onto a generic UpdateResult that drops
      // the cause, so log the extractor's reason here to keep it observable.
      Log.w('extractArchive: failed to extract release archive: ${result.failureReason}');
    }
    return result.succeeded;
  }

  String _publishedAssetFileName({required String assetUrl}) {
    final Uri uri = Uri.parse(assetUrl);
    final String assetFileName = p.url.basename(uri.path);
    if (assetFileName.isEmpty) {
      throw StateError('Release asset URL does not contain a filename: $assetUrl');
    }
    return assetFileName;
  }
}
