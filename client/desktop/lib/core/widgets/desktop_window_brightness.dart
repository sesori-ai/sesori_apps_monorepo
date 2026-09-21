import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Keeps the native window chrome as light or dark as the app, so the two never
/// disagree. The host can only force a value, so every change of the effective
/// brightness is pushed again: the in-app mode, or the system's while the app
/// follows it.
class const DesktopWindowBrightness({
  super.key,
  required final WindowHost windowHost,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<DesktopWindowBrightness> createState() => _DesktopWindowBrightnessState();
}

class _DesktopWindowBrightnessState() extends State<DesktopWindowBrightness> {
  Brightness? _pushed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (brightness == _pushed) return;
    _pushed = brightness;
    unawaited(_push(brightness: brightness));
  }

  Future<void> _push({required Brightness brightness}) async {
    try {
      await widget.windowHost.setBrightness(
        brightness: switch (brightness) {
          Brightness.light => WindowBrightness.light,
          Brightness.dark => WindowBrightness.dark,
        },
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to match the native window chrome to the app's brightness", error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
