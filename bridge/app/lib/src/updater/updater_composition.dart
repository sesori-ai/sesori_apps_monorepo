import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart'
    show ArchiveExtractor, BinaryDownloadClient, ChecksumValidator, DownloadProgress, bridgeVersion;

import '../foundation/filesystem_cleaner.dart';
import '../foundation/process_runner.dart';
import '../foundation/process_runner_command_executor.dart';
import 'api/checksum_manifest_api.dart';
import 'api/github_releases_api.dart';
import 'api/managed_runtime_manifest_api.dart';
import 'api/platform_update_api.dart';
import 'api/update_attempt_api.dart';
import 'api/update_cache_api.dart';
import 'api/update_log_api.dart';
import 'foundation/release_track.dart';
import 'foundation/update_lock.dart';
import 'models/distribution_target.dart';
import 'models/managed_runtime_paths.dart';
import 'repositories/release_repository.dart';
import 'repositories/update_artifact_repository.dart';
import 'repositories/update_attempt_repository.dart';
import 'repositories/update_installation_repository.dart';
import 'repositories/update_log_repository.dart';
import 'services/update_apply_service.dart';
import 'services/update_install_service.dart';

/// Builds the updater collaborators that both the explicit `update` command and
/// the resident bridge's background updater need. Each runs in its own process
/// and builds its own set; this only keeps the wiring in one place.
///
/// [workspaceLabel] separates a concurrent stager's archive and staging paths
/// from the shared, fixed ones (see [UpdateInstallService]).
({
  ReleaseRepository releaseRepository,
  UpdateInstallService installService,
  UpdateApplyService applyService,
  UpdateLogRepository logRepository,
  UpdateAttemptRepository attemptRepository,
  UpdateInstallationRepository installationRepository,
  UpdateLock updateLock,
})
composeUpdater({
  required http.Client httpClient,
  required ProcessRunner processRunner,
  required ManagedRuntimePaths managedRuntimePaths,
  required ReleaseTrack releaseTrack,
  required Map<String, String> environment,
  required StreamSink<DownloadProgress> progressSink,
  required String? workspaceLabel,
}) {
  const clock = Clock();
  const filesystemCleaner = FilesystemCleaner();
  final installRoot = managedRuntimePaths.installRoot;
  final distributionTarget = DistributionTarget.current();

  // Opportunistically authenticate GitHub release checks. Unauthenticated
  // requests share a 60/hour per-IP budget that is easily exhausted behind
  // shared or NAT'd networks; a token lifts it to 5000/hour. The first
  // non-empty value wins, so a blank GITHUB_TOKEN does not shadow GH_TOKEN.
  final githubToken = [
    environment['GITHUB_TOKEN'],
    environment['GH_TOKEN'],
  ].map((token) => token?.trim()).firstWhere((token) => token != null && token.isNotEmpty, orElse: () => null);

  final logRepository = UpdateLogRepository(
    api: UpdateLogApi(installRoot: installRoot, clock: clock),
  );
  final attemptRepository = UpdateAttemptRepository(api: UpdateAttemptApi(installRoot: installRoot));
  final installationRepository = UpdateInstallationRepository(
    platformUpdateApi: PlatformUpdateApi.forPlatform(processRunner: processRunner),
    manifestApi: const ManagedRuntimeManifestApi(),
  );
  final updateLock = UpdateLock(currentPid: pid, processRunner: processRunner, clock: clock);

  return (
    releaseRepository: ReleaseRepository(
      api: GitHubReleasesApi(httpClient: httpClient, authToken: githubToken),
      cache: UpdateCacheApi(cacheDirectory: managedRuntimePaths.cacheDirectory, clock: clock),
      currentVersion: bridgeVersion,
      target: distributionTarget,
      track: releaseTrack,
    ),
    installService: UpdateInstallService(
      updateArtifactRepository: UpdateArtifactRepository(
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        checksumManifestApi: ChecksumManifestApi(httpClient: httpClient),
        checksumValidator: ChecksumValidator(),
        archiveExtractor: ArchiveExtractor(
          commandExecutor: ProcessRunnerCommandExecutor(processRunner: processRunner),
        ),
        archiveFormat: distributionTarget.archiveFormat,
        progressSink: progressSink,
      ),
      filesystemCleaner: filesystemCleaner,
      workspaceLabel: workspaceLabel,
    ),
    applyService: UpdateApplyService(
      installationRepository: installationRepository,
      attemptRepository: attemptRepository,
      logRepository: logRepository,
      updateLock: updateLock,
      filesystemCleaner: filesystemCleaner,
      clock: clock,
      currentVersion: bridgeVersion,
      installRoot: installRoot,
    ),
    logRepository: logRepository,
    attemptRepository: attemptRepository,
    installationRepository: installationRepository,
    updateLock: updateLock,
  );
}
