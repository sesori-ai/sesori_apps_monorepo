import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/application_support_directory_client.dart";
import "package:sesori_mobile/core/platform/file_attribution_claim_storage.dart";

void main() {
  late Directory applicationSupportDirectory;
  late FileAttributionClaimStorage storage;

  setUp(() async {
    applicationSupportDirectory = await Directory.systemTemp.createTemp("sesori-attribution-claims-");
    storage = FileAttributionClaimStorage(
      directoryClient: ApplicationSupportDirectoryClient.forTesting(
        load: () async => applicationSupportDirectory,
      ),
    );
  });

  tearDown(() {
    if (applicationSupportDirectory.existsSync()) {
      applicationSupportDirectory.deleteSync(recursive: true);
    }
  });

  test("persists independent one-shot claims across storage instances", () async {
    expect(await storage.isClaimed(event: AttributionEvent.bridgePaired), isFalse);
    expect(await storage.isClaimed(event: AttributionEvent.firstSessionRun), isFalse);

    await storage.markClaimed(event: AttributionEvent.bridgePaired);

    expect(await storage.isClaimed(event: AttributionEvent.bridgePaired), isTrue);
    expect(await storage.isClaimed(event: AttributionEvent.firstSessionRun), isFalse);

    final restartedStorage = FileAttributionClaimStorage(
      directoryClient: ApplicationSupportDirectoryClient.forTesting(
        load: () async => applicationSupportDirectory,
      ),
    );
    expect(await restartedStorage.isClaimed(event: AttributionEvent.bridgePaired), isTrue);
  });

  test("a new app-container directory starts with no claims", () async {
    await storage.markClaimed(event: AttributionEvent.firstSessionRun);
    expect(await storage.isClaimed(event: AttributionEvent.firstSessionRun), isTrue);

    final newInstallationDirectory = await Directory.systemTemp.createTemp("sesori-attribution-reinstall-");
    addTearDown(() {
      if (newInstallationDirectory.existsSync()) {
        newInstallationDirectory.deleteSync(recursive: true);
      }
    });
    final reinstalledStorage = FileAttributionClaimStorage(
      directoryClient: ApplicationSupportDirectoryClient.forTesting(
        load: () async => newInstallationDirectory,
      ),
    );

    expect(await reinstalledStorage.isClaimed(event: AttributionEvent.firstSessionRun), isFalse);
  });
}
