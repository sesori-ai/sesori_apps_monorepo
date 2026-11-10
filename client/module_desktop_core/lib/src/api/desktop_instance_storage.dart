import "dart:convert";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/desktop_attention_preference.dart";
import "../foundation/desktop_automatic_updates.dart";
import "../foundation/desktop_sidebar_layout.dart";
import "../foundation/desktop_text_size.dart";
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
  static const String _automaticUpdatesFileName = "automatic-updates";
  static const String _textSizeFileName = "text-size";

  Future<BridgeProcessDesiredState?> readBridgeDesiredState() async {
    final File file = await _desiredStateFile();
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) {
      return null;
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

  Future<DesktopAutomaticUpdates> readAutomaticUpdates() async {
    final File file = await _fileNamed(fileName: _automaticUpdatesFileName);
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) {
      return DesktopAutomaticUpdates.enabled;
    }
    final value = (await file.readAsString()).trim();
    for (final preference in DesktopAutomaticUpdates.values) {
      if (preference.name == value) {
        return preference;
      }
    }
    logw("Ignoring an invalid persisted desktop automatic-updates preference");
    return DesktopAutomaticUpdates.enabled;
  }

  Future<void> writeAutomaticUpdates({required DesktopAutomaticUpdates preference}) async {
    final File file = await _fileNamed(fileName: _automaticUpdatesFileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(preference.name, flush: true);
  }

  /// The stored text size, or [DesktopTextSize.standard] when none was chosen
  /// or it cannot be read: it is read before the first frame, and a text size
  /// is never worth failing startup over.
  Future<DesktopTextSize> readTextSize() async {
    try {
      final file = await _fileNamed(fileName: _textSizeFileName);
      // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
      if (!await file.exists()) return DesktopTextSize.standard;
      final value = (await file.readAsString()).trim();
      for (final size in DesktopTextSize.values) {
        if (size.name == value) return size;
      }
      logw("Ignoring an invalid persisted desktop text size");
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop text size", error, stackTrace);
    }
    return DesktopTextSize.standard;
  }

  Future<void> writeTextSize({required DesktopTextSize size}) async {
    final file = await _fileNamed(fileName: _textSizeFileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(size.name, flush: true);
  }

  Future<DesktopSidebarLayout> readSidebarLayout() async {
    final file = await _fileNamed(fileName: "sidebar-layout");
    // ignore: avoid_slow_async_io, one startup read must not block the UI isolate
    if (!await file.exists()) return const DesktopSidebarLayout();
    return DesktopSidebarLayout.fromJson(jsonDecodeMap(await file.readAsString()));
  }

  Future<void> writeSidebarLayout({required DesktopSidebarLayout layout}) async {
    final file = await _fileNamed(fileName: "sidebar-layout");
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(layout.toJson()), flush: true);
  }

  Future<File> _desiredStateFile() => _fileNamed(fileName: _desiredStateFileName);

  Future<File> _fileNamed({required String fileName}) async {
    final Directory root = await _applicationSupportDirectory.resolve();
    return File(path.join(root.path, _directoryName, fileName));
  }
}
