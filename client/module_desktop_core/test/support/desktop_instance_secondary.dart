import "dart:io";

import "package:sesori_desktop_core/sesori_desktop_core.dart";

Future<void> main(List<String> arguments) async {
  final DesktopInstanceApi api = DesktopInstanceApi.forTesting(
    applicationSupportDirectory: _FixedApplicationSupportDirectory(directory: Directory(arguments.single)),
    activationAttempts: 3,
    activationRetryDelay: const Duration(milliseconds: 1),
    connectTimeout: const Duration(milliseconds: 100),
    readTimeout: const Duration(milliseconds: 100),
  );
  try {
    if (await api.tryAcquirePrimary()) {
      stdout.writeln("primary");
      return;
    }
    stdout.writeln(await api.signalPrimary() ? "secondaryActivated" : "secondaryActivationFailed");
  } finally {
    await api.dispose();
  }
}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
