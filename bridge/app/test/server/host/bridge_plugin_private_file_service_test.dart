import "dart:io";

import "package:sesori_bridge/src/server/host/bridge_plugin_private_file_service.dart";
import "package:test/test.dart";

void main() {
  test("writes owner-only adapter files and deletes them", () async {
    final directory = await Directory.systemTemp.createTemp("plugin-private-files-");
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final service = BridgePluginPrivateFileService(stateDirectory: directory.path);

    final filePath = await service.write(name: "adapter.json", contents: "secret");

    expect(await File(filePath).readAsString(), "secret");
    if (!Platform.isWindows) {
      expect(FileStat.statSync(directory.path).mode & 0x1ff, 0x1c0);
      expect(FileStat.statSync(filePath).mode & 0x1ff, 0x180);
    }
    await service.delete(name: "adapter.json");
    expect(File(filePath).existsSync(), isFalse);
  });

  test("rejects paths outside the plugin state directory", () async {
    final directory = await Directory.systemTemp.createTemp("plugin-private-files-");
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final service = BridgePluginPrivateFileService(stateDirectory: directory.path);

    expect(
      () => service.write(name: "../secret", contents: "secret"),
      throwsArgumentError,
    );
  });
}
