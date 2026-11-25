import "dart:io";

import "package:sesori_bridge/src/api/sesori_skill_bundle_storage.dart";
import "package:test/test.dart";

/// A skill bundle folder of the test's own, removed after it.
SesoriSkillBundleStorage temporarySkillBundleStorage() {
  final directory = Directory.systemTemp.createTempSync("sesori-agent-skills-");
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return SesoriSkillBundleStorage(directoryPath: directory.path);
}
