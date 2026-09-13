import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync("host-executable-locator");
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) temporaryDirectory.deleteSync(recursive: true);
  });

  test("finds a PATH file even when launching it could fail", () {
    File(p.join(temporaryDirectory.path, "runtime")).writeAsStringSync("#!/missing-interpreter\n");
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(
        executable: "runtime",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      HostExecutablePresence.present,
    );
  });

  test("reports an absent POSIX PATH command", () {
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(
        executable: "runtime",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      HostExecutablePresence.absent,
    );
  });

  test("uses case-insensitive Windows environment keys and PATHEXT", () {
    File(p.join(temporaryDirectory.path, "runtime.CMD")).writeAsStringSync("@echo off");
    const locator = IoHostExecutableLocator(platformIsWindows: true);

    expect(
      locator.locate(
        executable: "runtime",
        environment: {"Path": temporaryDirectory.path, "PathExt": ".CMD;.EXE"},
        workingDirectory: null,
      ),
      HostExecutablePresence.present,
    );
  });

  test("checks the Windows working directory before PATH", () {
    final pathDirectory = Directory.systemTemp.createTempSync("host-executable-path");
    addTearDown(() {
      if (pathDirectory.existsSync()) pathDirectory.deleteSync(recursive: true);
    });
    File(p.join(temporaryDirectory.path, "runtime.CMD")).writeAsStringSync("@echo off");
    const locator = IoHostExecutableLocator(platformIsWindows: true);

    expect(
      locator.locate(
        executable: "runtime",
        environment: {"PATH": pathDirectory.path, "PATHEXT": ".CMD;.EXE"},
        workingDirectory: temporaryDirectory.path,
      ),
      HostExecutablePresence.present,
    );
  });

  test("inspects an explicit path directly", () {
    final executable = File(p.join(temporaryDirectory.path, "runtime"))..writeAsStringSync("runtime");
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(executable: executable.path, environment: const {}, workingDirectory: null),
      HostExecutablePresence.present,
    );
  });
}
