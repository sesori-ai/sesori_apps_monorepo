import "dart:async";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Dumb adapter for the macOS runner's app-menu items; see
/// `MainFlutterWindow+AppMenu.swift`. Other platforms have no such menu, so
/// the channel never calls and [commands] stays silent.
@LazySingleton(as: DesktopAppMenu)
class MethodChannelDesktopAppMenu.forTesting({required final MethodChannel _channel}) implements DesktopAppMenu {
  new() : this.forTesting(channel: const MethodChannel("sesori/app_menu"));

  @visibleForTesting
  this {
    _channel.setMethodCallHandler(_onRunnerCall);
  }

  final StreamController<DesktopAppMenuCommand> _commands = StreamController<DesktopAppMenuCommand>.broadcast(
    sync: true,
  );

  @override
  Stream<DesktopAppMenuCommand> get commands => _commands.stream;

  Future<void> _onRunnerCall(MethodCall call) async {
    final command = switch (call.method) {
      "increaseTextSize" => DesktopAppMenuCommand.increaseTextSize,
      "decreaseTextSize" => DesktopAppMenuCommand.decreaseTextSize,
      "resetTextSize" => DesktopAppMenuCommand.resetTextSize,
      _ => throw MissingPluginException(),
    };
    _commands.add(command);
  }
}
