import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/io_file_access_permission.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

class _Launcher() extends Mock implements UrlLauncher;

void main() {
  final settings = Uri.parse("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles");
  late _Launcher launcher;
  setUp(() {
    launcher = _Launcher();
    when(() => launcher.launch(settings)).thenAnswer((_) async => true);
  });

  test("macOS checks only the protected path and opens the correct settings pane", () async {
    String? probed;
    final permission = IoFileAccessPermission.forTesting(
      urlLauncher: launcher,
      isMacOS: true,
      homeDirectory: "/synthetic/home",
      probe: ({required filePath}) async {
        probed = filePath;
      },
    );
    expect(await permission.check(), FileAccessStatus.granted);
    expect(probed, "/synthetic/home/Library/Application Support/com.apple.TCC/TCC.db");
    await permission.openSystemSettings();
    verify(() => launcher.launch(settings)).called(1);
    when(() => launcher.launch(settings)).thenAnswer((_) async => false);
    await expectLater(permission.openSystemSettings(), throwsStateError);
  });

  for (final code in [1, 13, 2, 5]) {
    test("errno $code distinguishes denied from indeterminate access", () async {
      final permission = IoFileAccessPermission.forTesting(
        urlLauncher: launcher,
        isMacOS: true,
        homeDirectory: "/synthetic/home",
        probe: ({required filePath}) async => throw FileSystemException("fixture", filePath, OSError("fixture", code)),
      );
      expect(await permission.check(), code == 1 || code == 13 ? FileAccessStatus.denied : FileAccessStatus.unknown);
    });
  }

  test("unsupported platforms and missing home never probe a protected file", () async {
    for (final macOS in [false, true]) {
      final permission = IoFileAccessPermission.forTesting(
        urlLauncher: launcher,
        isMacOS: macOS,
        homeDirectory: null,
        probe: ({required filePath}) async => fail("unexpected I/O"),
      );
      expect(await permission.check(), macOS ? FileAccessStatus.unknown : FileAccessStatus.unsupported);
      if (!macOS) await permission.openSystemSettings();
    }
    verifyNever(() => launcher.launch(settings));
  });
}
