import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as p;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "application_support_directory_client.dart";

@LazySingleton(as: AttributionClaimStorage)
class FileAttributionClaimStorage({
  required final ApplicationSupportDirectoryClient _directoryClient,
}) implements AttributionClaimStorage {
  static const _directoryName = "attribution_claims";

  @override
  Future<bool> isClaimed({required String claimKey}) async {
    final file = await _claimFile(claimKey: claimKey);
    // Claim checks can happen during a user interaction, so keep filesystem
    // metadata work off the Flutter isolate.
    // ignore: avoid_slow_async_io
    return await file.exists();
  }

  @override
  Future<void> markClaimed({required String claimKey}) async {
    final file = await _claimFile(claimKey: claimKey);
    await file.parent.create(recursive: true);
    await file.writeAsString("claimed", flush: true);
  }

  Future<File> _claimFile({required String claimKey}) async {
    final root = await _directoryClient.directory;
    return File(p.join(root.path, _directoryName, claimKey));
  }
}
