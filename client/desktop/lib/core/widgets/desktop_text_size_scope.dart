import "dart:async";

import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "desktop_command_palette.dart";

/// Draws every text in the window at the chosen [DesktopTextSize], on top of
/// the system's own text scaling, and binds the zoom shortcuts that change it:
/// Cmd/Ctrl with = or + for larger, - for smaller and 0 for the default.
///
/// Sits above the root navigator, so routes, dialogs and menus all scale.
class const DesktopTextSizeScope({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = context.watch<DesktopTextSizeCubit>().state;
    final cubit = context.read<DesktopTextSizeCubit>();
    final media = MediaQuery.of(context);
    void increase() => unawaited(cubit.increase());
    void decrease() => unawaited(cubit.decrease());
    void reset() => unawaited(cubit.reset());

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // "+" is Shift+= on most layouts and a key of its own on some.
        for (final key in [LogicalKeyboardKey.equal, LogicalKeyboardKey.add]) ...{
          desktopShortcut(key: key): increase,
          desktopShortcut(key: key, shift: true): increase,
        },
        desktopShortcut(key: LogicalKeyboardKey.numpadAdd): increase,
        desktopShortcut(key: LogicalKeyboardKey.minus): decrease,
        desktopShortcut(key: LogicalKeyboardKey.numpadSubtract): decrease,
        desktopShortcut(key: LogicalKeyboardKey.digit0): reset,
        desktopShortcut(key: LogicalKeyboardKey.numpad0): reset,
      },
      child: MediaQuery(
        // ponytail: desktop system scalers are linear, so scale(1) is their whole
        // factor; a nonlinear one would need a composing TextScaler subclass.
        data: media.copyWith(textScaler: TextScaler.linear(media.textScaler.scale(1) * size.scale)),
        child: child,
      ),
    );
  }
}
