import "dart:io";

import "package:sesori_bridge/src/api/sesori_skill_bundle_storage.dart";
import "package:sesori_bridge/src/repositories/sesori_skill_bundle_repository.dart";
import "package:test/test.dart";

/// Skill bundles in a folder of the test's own, removed after it.
SesoriSkillBundleRepository temporarySkillBundles() {
  final directory = Directory.systemTemp.createTempSync("sesori-agent-skills-");
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return SesoriSkillBundleRepository(storage: SesoriSkillBundleStorage(directoryPath: directory.path));
}
