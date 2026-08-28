import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/platform/desktop_application_support_directory.dart";

/// Layer-1 persistence boundary for desktop-owned last desired bridge state.
@lazySingleton
class DesktopInstanceStorage._create({
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
}) {
  new({required DesktopApplicationSupportDirectory applicationSupportDirectory})
    : this._create(applicationSupportDirectory: applicationSupportDirectory);

  static const String _directoryName = "desktop-instance";
  static const String _desiredStateFileName = "bridge-desired-state";

  Future<BridgeProcessDesiredState> readBridgeDesiredState() async {
    final File file = await _desiredStateFile();
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) {
      return BridgeProcessDesiredState.off;
    }
    final String value = (await file.readAsString()).trim();
    for (final BridgeProcessDesiredState state in BridgeProcessDesiredState.values) {
      if (state.name == value) {
        return state;
      }
    }
    logw("Ignoring an invalid persisted desktop bridge desired state");
    return BridgeProcessDesiredState.off;
  }

  Future<void> writeBridgeDesiredState({required BridgeProcessDesiredState state}) async {
    final File file = await _desiredStateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(state.name, flush: true);
  }

  Future<File> _desiredStateFile() async {
    final Directory root = await _applicationSupportDirectory.resolve();
    return File(path.join(root.path, _directoryName, _desiredStateFileName));
  }
}
