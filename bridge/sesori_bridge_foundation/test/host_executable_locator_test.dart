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

  test("finds a POSIX PATH command whose name contains a backslash", () {
    File(p.join(temporaryDirectory.path, r"foo\bar")).writeAsStringSync("runtime");
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(
        executable: r"foo\bar",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      HostExecutablePresence.present,
    );
  }, skip: Platform.isWindows);

  test("resolves relative PATH entries from the requested working directory", () {
    final workingDirectory = Directory(p.join(temporaryDirectory.path, "workspace"))..createSync();
    final binDirectory = Directory(p.join(workingDirectory.path, "bin"))..createSync();
    File(p.join(binDirectory.path, "runtime")).writeAsStringSync("runtime");
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(
        executable: "runtime",
        environment: const {"PATH": "bin"},
        workingDirectory: workingDirectory.path,
      ),
      HostExecutablePresence.present,
    );
  });

  test("rejects an empty command without treating PATH directories as executables", () {
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(executable: "", environment: {"PATH": temporaryDirectory.path}, workingDirectory: null),
      HostExecutablePresence.unknown,
    );
  });

  test("keeps an unreadable PATH entry indeterminate", () {
    final lockedDirectory = Directory(p.join(temporaryDirectory.path, "locked"))..createSync();
    final chmodResult = Process.runSync("chmod", ["000", lockedDirectory.path]);
    expect(chmodResult.exitCode, 0);
    addTearDown(() => Process.runSync("chmod", ["700", lockedDirectory.path]));
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.locate(executable: "runtime", environment: {"PATH": lockedDirectory.path}, workingDirectory: null),
      HostExecutablePresence.unknown,
    );
  }, skip: Platform.isWindows);

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
    expect(
      locator.isPathCommandAbsent(
        executable: "runtime",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      isTrue,
    );
  });

  test("does not treat present or indeterminate PATH entries as absent", () {
    File(p.join(temporaryDirectory.path, "runtime")).writeAsStringSync("runtime");
    const locator = IoHostExecutableLocator(platformIsWindows: false);

    expect(
      locator.isPathCommandAbsent(
        executable: "runtime",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      isFalse,
    );
    expect(
      locator.isPathCommandAbsent(
        executable: "runtime",
        environment: const {"PATH": "\u0000"},
        workingDirectory: null,
      ),
      isFalse,
    );
  });

  test("classifies command-not-found process errors by platform", () {
    const posixLocator = IoHostExecutableLocator(platformIsWindows: false);
    const windowsLocator = IoHostExecutableLocator(platformIsWindows: true);
    const errorCodeTwo = ProcessException("runtime", [], "missing", 2);
    const errorCodeThree = ProcessException("runtime", [], "missing", 3);
    const permissionDenied = ProcessException("runtime", [], "denied", 13);

    expect(posixLocator.isProcessMissingError(error: errorCodeTwo), isTrue);
    expect(posixLocator.isProcessMissingError(error: errorCodeThree), isFalse);
    expect(windowsLocator.isProcessMissingError(error: errorCodeTwo), isTrue);
    expect(windowsLocator.isProcessMissingError(error: errorCodeThree), isTrue);
    expect(windowsLocator.isProcessMissingError(error: permissionDenied), isFalse);
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
