import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as p;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "application_support_directory_client.dart";

@LazySingleton(as: AttributionClaimStorage)
class FileAttributionClaimStorage({
  required final ApplicationSupportDirectoryClient _directoryClient,
}) implements AttributionClaimStorage {
  static const _directoryName = "singular_attribution_claims";

  @override
  Future<bool> isClaimed({required AttributionEvent event}) async => (await _claimFile(event: event)).existsSync();

  @override
  Future<void> markClaimed({required AttributionEvent event}) async {
    final file = await _claimFile(event: event);
    await file.parent.create(recursive: true);
    await file.writeAsString("claimed", flush: true);
  }

  Future<File> _claimFile({required AttributionEvent event}) async {
    final root = await _directoryClient.directory;
    return File(p.join(root.path, _directoryName, _fileName(event: event)));
  }

  String _fileName({required AttributionEvent event}) => switch (event) {
    AttributionEvent.bridgePaired => "bridge_paired_v1",
    AttributionEvent.firstSessionRun => "first_session_run_v1",
    AttributionEvent.accountCreated || AttributionEvent.accountLogin => throw ArgumentError.value(
      event,
      "event",
      "Only one-shot attribution events can be claimed",
    ),
  };
}
