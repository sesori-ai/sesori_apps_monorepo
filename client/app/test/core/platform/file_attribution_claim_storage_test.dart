import "dart:io";

import "package:flutter_test/flutter_test.dart";
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
    expect(await storage.isClaimed(claimKey: "bridge_paired_v1"), isFalse);
    expect(await storage.isClaimed(claimKey: "first_session_run_v1"), isFalse);

    await storage.markClaimed(claimKey: "bridge_paired_v1");

    expect(await storage.isClaimed(claimKey: "bridge_paired_v1"), isTrue);
    expect(await storage.isClaimed(claimKey: "first_session_run_v1"), isFalse);

    final restartedStorage = FileAttributionClaimStorage(
      directoryClient: ApplicationSupportDirectoryClient.forTesting(
        load: () async => applicationSupportDirectory,
      ),
    );
    expect(await restartedStorage.isClaimed(claimKey: "bridge_paired_v1"), isTrue);
  });

  test("a new app-container directory starts with no claims", () async {
    await storage.markClaimed(claimKey: "first_session_run_v1");
    expect(await storage.isClaimed(claimKey: "first_session_run_v1"), isTrue);

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

    expect(await reinstalledStorage.isClaimed(claimKey: "first_session_run_v1"), isFalse);
  });
}
