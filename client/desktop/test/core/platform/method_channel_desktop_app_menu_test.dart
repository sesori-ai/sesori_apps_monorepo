import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/method_channel_desktop_app_menu.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel("sesori/app_menu/test");

  Future<ByteData?> runnerCalls(String method) {
    final completer = Completer<ByteData?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method)),
      completer.complete,
    );
    return completer.future;
  }

  test("relays the runner's text-size menu items as commands", () async {
    final menu = MethodChannelDesktopAppMenu.forTesting(channel: channel);
    final commands = <DesktopAppMenuCommand>[];
    menu.commands.listen(commands.add);

    await runnerCalls("increaseTextSize");
    await runnerCalls("decreaseTextSize");
    await runnerCalls("resetTextSize");
    final unknown = await runnerCalls("somethingElse");

    expect(commands, [
      DesktopAppMenuCommand.increaseTextSize,
      DesktopAppMenuCommand.decreaseTextSize,
      DesktopAppMenuCommand.resetTextSize,
    ]);
    // An unknown method answers "not implemented" (an empty reply) instead of a command.
    expect(unknown, isNull);
  });
}
