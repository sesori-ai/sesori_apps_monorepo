import "dart:convert";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/desktop_attention_preference.dart";
import "../foundation/platform/desktop_application_support_directory.dart";
import "../foundation/platform/window_host.dart";

/// Layer-1 persistence boundary for desktop-owned instance state.
@lazySingleton
class DesktopInstanceStorage._create({
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
}) {
  new({required DesktopApplicationSupportDirectory applicationSupportDirectory})
    : this._create(applicationSupportDirectory: applicationSupportDirectory);

  static const String _directoryName = "desktop-instance";
  static const String _desiredStateFileName = "bridge-desired-state";
  static const String _windowBoundsFileName = "window-bounds";
  static const String _attentionPreferenceFileName = "attention-notifications";

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
    final File file = await _fileNamed(fileName: _desiredStateFileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(state.name, flush: true);
  }

  Future<WindowBounds?> readWindowBounds() async {
    final File file = await _fileNamed(fileName: _windowBoundsFileName);
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) {
      return null;
    }
    final List<String> components = const LineSplitter().convert(await file.readAsString());
    if (components.length != 4) {
      logw("Ignoring invalid persisted desktop window bounds");
      return null;
    }
    final left = double.tryParse(components[0]);
    final top = double.tryParse(components[1]);
    final width = double.tryParse(components[2]);
    final height = double.tryParse(components[3]);
    if (left == null || top == null || width == null || height == null) {
      logw("Ignoring invalid persisted desktop window bounds");
      return null;
    }
    return WindowBounds(left: left, top: top, width: width, height: height);
  }

  Future<void> writeWindowBounds({required WindowBounds bounds}) async {
    final File file = await _fileNamed(fileName: _windowBoundsFileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      <double>[bounds.left, bounds.top, bounds.width, bounds.height].join("\n"),
      flush: true,
    );
  }

  Future<DesktopAttentionPreference> readAttentionPreference() async {
    final File file = await _fileNamed(fileName: _attentionPreferenceFileName);
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) {
      return DesktopAttentionPreference.enabled;
    }
    final value = (await file.readAsString()).trim();
    for (final preference in DesktopAttentionPreference.values) {
      if (preference.name == value) {
        return preference;
      }
    }
    logw("Ignoring an invalid persisted desktop attention preference");
    return DesktopAttentionPreference.enabled;
  }

  Future<void> writeAttentionPreference({required DesktopAttentionPreference preference}) async {
    final File file = await _fileNamed(fileName: _attentionPreferenceFileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(preference.name, flush: true);
  }

  Future<File> _desiredStateFile() => _fileNamed(fileName: _desiredStateFileName);

  Future<File> _fileNamed({required String fileName}) async {
    final Directory root = await _applicationSupportDirectory.resolve();
    return File(path.join(root.path, _directoryName, fileName));
  }
}
