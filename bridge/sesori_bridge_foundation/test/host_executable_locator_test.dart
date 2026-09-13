import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

({String directory, File file}) _createWindowsFile({
  required Directory temporaryDirectory,
  required String fileName,
}) {
  final directory = Platform.isWindows
      ? temporaryDirectory.path
      : "C:\\sesori-${p.basename(temporaryDirectory.path)}.v1";
  final file = File(p.Context(style: p.Style.windows).join(directory, fileName))..writeAsStringSync("runtime");
  if (!Platform.isWindows) addTearDown(file.deleteSync);
  return (directory: directory, file: file);
}

void main() {
  const posixLocator = IoHostExecutableLocator(platformIsWindows: false);
  const windowsLocator = IoHostExecutableLocator(platformIsWindows: true);
  final windowsPaths = p.Context(style: p.Style.windows);
  late Directory temporaryDirectory;

  setUp(() => temporaryDirectory = Directory.systemTemp.createTempSync("host-executable-locator"));
  tearDown(() {
    if (temporaryDirectory.existsSync()) temporaryDirectory.deleteSync(recursive: true);
  });

  test("finds a PATH file even when launching it could fail", () {
    File(p.join(temporaryDirectory.path, "runtime")).writeAsStringSync("#!/missing-interpreter\n");

    expect(
      posixLocator.locate(
        executable: "runtime",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      HostExecutablePresence.present,
    );
  });

  test("finds a POSIX PATH command whose name contains a backslash", () {
    File(p.join(temporaryDirectory.path, r"foo\bar")).writeAsStringSync("runtime");

    expect(
      posixLocator.locate(
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

    expect(
      posixLocator.locate(
        executable: "runtime",
        environment: const {"PATH": "bin"},
        workingDirectory: workingDirectory.path,
      ),
      HostExecutablePresence.present,
    );
  });

  test("preserves whitespace in POSIX PATH entries", () {
    final pathDirectory = Directory(p.join(temporaryDirectory.path, " bin"))..createSync();
    File(p.join(pathDirectory.path, "runtime")).writeAsStringSync("runtime");

    expect(
      posixLocator.locate(
        executable: "runtime",
        environment: const {"PATH": " bin"},
        workingDirectory: temporaryDirectory.path,
      ),
      HostExecutablePresence.present,
    );
  }, skip: Platform.isWindows);

  test("rejects an empty command without treating PATH directories as executables", () {
    expect(
      posixLocator.locate(executable: "", environment: {"PATH": temporaryDirectory.path}, workingDirectory: null),
      HostExecutablePresence.unknown,
    );
  });

  test("keeps an unreadable PATH entry indeterminate", () {
    final lockedDirectory = Directory(p.join(temporaryDirectory.path, "locked"))..createSync();
    expect(Process.runSync("chmod", ["000", lockedDirectory.path]).exitCode, 0);
    addTearDown(() => Process.runSync("chmod", ["700", lockedDirectory.path]));

    expect(
      posixLocator.locate(executable: "runtime", environment: {"PATH": lockedDirectory.path}, workingDirectory: null),
      HostExecutablePresence.unknown,
    );
  }, skip: Platform.isWindows);

  test("reports an absent POSIX PATH command", () {
    final environment = {"PATH": temporaryDirectory.path};

    expect(
      posixLocator.locate(executable: "runtime", environment: environment, workingDirectory: null),
      HostExecutablePresence.absent,
    );
    expect(
      posixLocator.isPathCommandAbsent(executable: "runtime", environment: environment, workingDirectory: null),
      isTrue,
    );
  });

  test("does not treat present or indeterminate PATH entries as absent", () {
    File(p.join(temporaryDirectory.path, "runtime")).writeAsStringSync("runtime");

    expect(
      posixLocator.isPathCommandAbsent(
        executable: "runtime",
        environment: {"PATH": temporaryDirectory.path},
        workingDirectory: null,
      ),
      isFalse,
    );
    expect(
      posixLocator.isPathCommandAbsent(
        executable: "runtime",
        environment: const {"PATH": "\u0000"},
        workingDirectory: null,
      ),
      isFalse,
    );
  });

  test("classifies command-not-found process errors by platform", () {
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
    final runtime = _createWindowsFile(temporaryDirectory: temporaryDirectory, fileName: "runtime.CMD");

    expect(
      windowsLocator.locate(
        executable: "runtime",
        environment: {"Path": runtime.directory, "PathExt": ".CMD;.EXE"},
        workingDirectory: null,
      ),
      HostExecutablePresence.present,
    );
  });

  test("applies PATHEXT without excluding exact Windows paths", () {
    final runtime = _createWindowsFile(temporaryDirectory: temporaryDirectory, fileName: "runtime.EXE");
    final exactRuntime = _createWindowsFile(temporaryDirectory: temporaryDirectory, fileName: "exact-runtime");
    const environment = {"PATHEXT": ".EXE"};

    expect(
      windowsLocator.locate(
        executable: windowsPaths.join(runtime.directory, "runtime"),
        environment: environment,
        workingDirectory: null,
      ),
      HostExecutablePresence.present,
    );
    expect(
      windowsLocator.locate(executable: exactRuntime.file.path, environment: environment, workingDirectory: null),
      HostExecutablePresence.present,
    );
  });

  test("checks the Windows working directory before PATH", () {
    final runtime = _createWindowsFile(temporaryDirectory: temporaryDirectory, fileName: "runtime.CMD");

    expect(
      windowsLocator.locate(
        executable: "runtime",
        environment: {"PATH": windowsPaths.join(runtime.directory, "missing"), "PATHEXT": ".CMD;.EXE"},
        workingDirectory: runtime.directory,
      ),
      HostExecutablePresence.present,
    );
  });

  test("inspects an explicit path directly", () {
    final executable = File(p.join(temporaryDirectory.path, "runtime"))..writeAsStringSync("runtime");

    expect(
      posixLocator.locate(executable: executable.path, environment: const {}, workingDirectory: null),
      HostExecutablePresence.present,
    );
  });
}
