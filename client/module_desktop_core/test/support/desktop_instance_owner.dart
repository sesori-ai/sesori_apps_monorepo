import "dart:async";
import "dart:io";

import "package:sesori_desktop_core/sesori_desktop_core.dart";

Future<void> main(List<String> arguments) async {
  final DesktopInstanceApi api = DesktopInstanceApi.forTesting(
    applicationSupportDirectory: _FixedApplicationSupportDirectory(directory: Directory(arguments.single)),
    activationAttempts: 1,
    activationRetryDelay: Duration.zero,
    connectTimeout: const Duration(milliseconds: 100),
    readTimeout: const Duration(milliseconds: 100),
  );
  if (!await api.tryAcquirePrimary()) {
    stderr.writeln("could not claim primary");
    exitCode = 2;
    return;
  }
  stdout.writeln("ready");
  await Completer<void>().future;
}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
