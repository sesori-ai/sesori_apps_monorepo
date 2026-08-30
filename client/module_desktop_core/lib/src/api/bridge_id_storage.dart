import "dart:convert";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../foundation/platform/desktop_application_support_directory.dart";
import "bridge_registration_record.dart";

/// Layer-1 persistence for the desktop GUI's last known bridge registration.
///
/// The registration and its owning account are intentionally kept in
/// desktop-owned application data rather than the bridge CLI's state directory:
/// the GUI must still be able to issue the idempotent unregister request after
/// the supervised helper has died, without submitting one account's id with a
/// different account's bearer token.
@lazySingleton
class BridgeIdStorage({required DesktopApplicationSupportDirectory applicationSupportDirectory}) {
  final DesktopApplicationSupportDirectory _applicationSupportDirectory = applicationSupportDirectory;

  static const String _directoryName = "desktop-instance";
  static const String _bridgeIdFileName = "bridge-id";

  Future<BridgeRegistrationRecord?> read() async {
    final File file = await _bridgeIdFile();
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) {
      return null;
    }
    final String contents = (await file.readAsString()).trim();
    if (contents.isEmpty) {
      return null;
    }
    return BridgeRegistrationRecord.fromJson(jsonDecodeMap(contents));
  }

  Future<void> write({required BridgeRegistrationRecord registration}) async {
    final File file = await _bridgeIdFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(registration.toJson()), flush: true);
  }

  Future<void> clear() async {
    final File file = await _bridgeIdFile();
    // ignore: avoid_slow_async_io, logout cleanup is already asynchronous
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _bridgeIdFile() async {
    final Directory root = await _applicationSupportDirectory.resolve();
    return File(path.join(root.path, _directoryName, _bridgeIdFileName));
  }
}
