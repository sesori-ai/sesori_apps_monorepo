import "dart:io";

import "package:clock/clock.dart";
import "package:http/http.dart" as http;

import "../../updater/api/archive_extractor_api.dart";
import "../../updater/api/checksum_manifest_api.dart";
import "../../updater/api/checksum_verifier_api.dart";
import "../../updater/api/file_replacement_api.dart";
import "../../updater/api/github_releases_api.dart";
import "../../updater/api/update_cache_api.dart";
import "../../updater/api/update_download_api.dart";
import "../../updater/platform_info.dart";
import "../../updater/repositories/installed_file_repository.dart";
import "../../updater/repositories/release_repository.dart";
import "../../updater/repositories/update_artifact_repository.dart";
import "../../updater/services/update_installer_service.dart";
import "../../updater/services/update_service.dart";
import "../../updater/update_lock.dart";
import "../../version.dart";
import "../foundation/process_runner.dart";

UpdateService buildUpdateService({required http.Client httpClient}) {
  final processRunner = ProcessRunner();
  final releaseRepository = ReleaseRepository(
    api: GitHubReleasesApi(httpClient: httpClient),
    cache: UpdateCacheApi(
      cacheDirectory: getCacheDirectory(),
      clock: const Clock(),
    ),
    currentVersion: appVersion,
    target: currentDistributionTarget(),
  );
  final updateArtifactRepository = UpdateArtifactRepository(
    downloadApi: UpdateDownloadApi(httpClient: httpClient),
    checksumManifestApi: ChecksumManifestApi(httpClient: httpClient),
    checksumVerifierApi: ChecksumVerifierApi(),
    archiveExtractorApi: ArchiveExtractorApi(processRunner: processRunner),
  );
  final installedFileRepository = InstalledFileRepository(
    fileReplacementApi: FileReplacementApi(processRunner: processRunner),
  );
  final updateInstallerService = UpdateInstallerService(
    updateArtifactRepository: updateArtifactRepository,
    updateLock: UpdateLock(
      currentPid: pid,
      processRunner: processRunner,
    ),
    installedFileRepository: installedFileRepository,
  );

  return UpdateService(
    releaseRepository: releaseRepository,
    updateInstallerService: updateInstallerService,
    executablePath: Platform.resolvedExecutable,
    managedExecutablePath: getBinaryPath(),
    environment: Platform.environment,
  );
}
