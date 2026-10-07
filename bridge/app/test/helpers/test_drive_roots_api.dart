import "package:sesori_bridge/src/api/drive_roots_api.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;

import "fake_process_runner.dart";

/// Windows drive letters, probed through the repository's filesystem API, so
/// a test needs no mount table or process to list drives.
final windowsDriveRootsApi = DriveRootsApi.forPlatform(
  platform: PlatformOs.windows,
  processRunner: NoopProcessRunner(),
  filesystemApi: const FilesystemApi(),
);
