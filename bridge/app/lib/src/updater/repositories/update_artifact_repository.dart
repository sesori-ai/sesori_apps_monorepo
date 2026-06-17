import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:path/path.dart' as p;

import '../api/archive_extractor_api.dart';
import '../api/checksum_manifest_api.dart';
import '../api/checksum_verifier_api.dart';
import '../api/update_download_api.dart';
import '../models/release_info.dart';
import '../models/update_result.dart';

class UpdateArtifactRepository {
  final UpdateDownloadApi _downloadApi;
  final ChecksumManifestApi _checksumManifestApi;
  final ChecksumVerifierApi _checksumVerifierApi;
  final ArchiveExtractorApi _archiveExtractorApi;

  UpdateArtifactRepository({
    required UpdateDownloadApi downloadApi,
    required ChecksumManifestApi checksumManifestApi,
    required ChecksumVerifierApi checksumVerifierApi,
    required ArchiveExtractorApi archiveExtractorApi,
  }) : _downloadApi = downloadApi,
       _checksumManifestApi = checksumManifestApi,
       _checksumVerifierApi = checksumVerifierApi,
       _archiveExtractorApi = archiveExtractorApi;

  Future<UpdateResult> downloadArchive({
    required ReleaseInfo release,
    required String archivePath,
  }) {
    return _downloadApi.downloadTo(
      url: release.assetUrl,
      destinationPath: archivePath,
    );
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

      return await _checksumVerifierApi.verify(
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
    } on Object {
      return false;
    }
  }

  Future<bool> extractArchive({
    required String archivePath,
    required String stagingPath,
  }) {
    return _archiveExtractorApi.extract(
      archivePath: archivePath,
      stagingPath: stagingPath,
    );
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
