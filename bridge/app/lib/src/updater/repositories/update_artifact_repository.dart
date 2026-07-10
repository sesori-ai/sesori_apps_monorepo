import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:path/path.dart' as p;
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../api/checksum_manifest_api.dart';
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
class UpdateArtifactRepository {
  final BinaryDownloadClient _downloadClient;
  final ChecksumManifestApi _checksumManifestApi;
  final ChecksumValidator _checksumValidator;
  final ArchiveExtractor _archiveExtractor;
  final ArchiveFormat _archiveFormat;
  final StreamSink<DownloadProgress> _progressSink;

  UpdateArtifactRepository({
    required BinaryDownloadClient downloadClient,
    required ChecksumManifestApi checksumManifestApi,
    required ChecksumValidator checksumValidator,
    required ArchiveExtractor archiveExtractor,
    required ArchiveFormat archiveFormat,
    required StreamSink<DownloadProgress> progressSink,
  }) : _downloadClient = downloadClient,
       _checksumManifestApi = checksumManifestApi,
       _checksumValidator = checksumValidator,
       _archiveExtractor = archiveExtractor,
       _archiveFormat = archiveFormat,
       _progressSink = progressSink;

  Future<UpdateResult> downloadArchive({
    required ReleaseInfo release,
    required String archivePath,
  }) async {
    try {
      // Forward each byte-progress event to the injected sink (a rendering
      // listener, or a no-listener drain). `forEach` completes with the stream's
      // error, so a thrown `DownloadException` is still caught and mapped below;
      // a connection-phase error (e.g. SocketException from the initial send)
      // propagates raw and is classified by the install service, as before.
      await _downloadClient
          .download(url: release.assetUrl, destinationPath: archivePath)
          .forEach(_progressSink.add);
      return UpdateResult.success;
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
    } on SocketException {
      // A network failure fetching the manifest is transient/benign — let it
      // propagate so the caller classifies it as a network error rather than a
      // genuine checksum mismatch (which warrants reinstall guidance).
      rethrow;
    } on TimeoutException {
      rethrow;
    } on HttpException {
      rethrow;
    } on ClientException {
      rethrow;
    } on Object catch (error, stackTrace) {
      // An unexpected error (e.g. a malformed manifest or a checksum read
      // failure) is a genuine verification failure, not a transient outage.
      // Log it so the degradation is observable instead of silently swallowed.
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
