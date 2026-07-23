import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

void main() {
  test("creates the database inside the supplied data directory", () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-database-path-test-");
    addTearDown(() async {
      if (temporaryDirectory.existsSync()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });
    final dataDirectory = path.join(temporaryDirectory.path, "account-a");
    final database = AppDatabase.create(dataDirectory: dataDirectory);

    try {
      await database.customSelect("SELECT 1").getSingle();
    } finally {
      await database.close();
    }

    expect(File(path.join(dataDirectory, "sesori.db")).existsSync(), isTrue);
  });
}
