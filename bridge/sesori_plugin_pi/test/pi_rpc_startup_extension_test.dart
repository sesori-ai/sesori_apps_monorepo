import "dart:io";

import "package:pi_plugin/src/api/pi_rpc_startup_extension.dart";
import "package:test/test.dart";

void main() {
  test("startup UI and native stdin handoff preserve the Pi RPC protocol", () async {
    final directory = await Directory.systemTemp.createTemp("pi-startup-test-");
    addTearDown(() => directory.delete(recursive: true));
    final extension = await File("${directory.path}${Platform.pathSeparator}startup.mjs")
        .writeAsString(piRpcStartupExtensionSource);
    final result = await Process.run("node", [
      "test/support/pi_rpc_startup_extension_test.mjs",
      extension.path,
    ]);
    expect(result.exitCode, 0, reason: "${result.stdout}\n${result.stderr}");
  });
}
