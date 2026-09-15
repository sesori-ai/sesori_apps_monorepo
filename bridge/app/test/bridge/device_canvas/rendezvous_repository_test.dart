import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/device_canvas/rendezvous_repository.dart";
import "package:test/test.dart";

void main() {
  group("DeviceCanvasRendezvousRepository", () {
    late Directory tempDir;
    late DeviceCanvasRendezvousRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("device-canvas-rendezvous-test-");
      repository = DeviceCanvasRendezvousRepository(dataDirectory: tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test("writes typed rendezvous with owner-only permissions on POSIX", () async {
      await repository.write(_rendezvous(port: 1234, secret: "secret-a"));

      expect((await repository.read())?.protocolVersion, equals(deviceCanvasIpcProtocolVersion));
      if (!Platform.isWindows) {
        expect(FileStat.statSync(repository.directoryPath).mode & 0x1ff, equals(0x1c0));
        expect(FileStat.statSync(repository.filePath).mode & 0x1ff, equals(0x180));
      }
    });

    test("atomically replaces the rendezvous file and removes temp files", () async {
      await repository.write(_rendezvous(port: 1, secret: "secret-a"));
      await repository.write(_rendezvous(port: 2, secret: "secret-b"));

      expect((await repository.read())?.port, equals(2));
      expect(File("${repository.filePath}.tmp").existsSync(), isFalse);
    });

    test("cleanup removes the rendezvous file", () async {
      await repository.write(_rendezvous(port: 1, secret: "secret-a"));

      await repository.delete();

      expect(File(repository.filePath).existsSync(), isFalse);
      expect(await repository.read(), isNull);
    });

    test("read fails explicitly for malformed or invalid rendezvous data", () async {
      await Directory(repository.directoryPath).create(recursive: true);
      await File(repository.filePath).writeAsString("not-json");
      await expectLater(repository.read(), throwsFormatException);

      await File(repository.filePath).writeAsString(
        '{"protocolVersion":1,"port":0,"bearerSecret":"secret","bridgeId":"bridge","processGeneration":"generation"}',
      );
      await expectLater(repository.read(), throwsFormatException);
    });

    test("stores rendezvous below the supplied data directory only", () {
      expect(repository.filePath, equals(path.join(tempDir.path, "device-canvas", "ipc-rendezvous.json")));
    });
  });
}

DeviceCanvasRendezvous _rendezvous({required int port, required String secret}) {
  return DeviceCanvasRendezvous(
    protocolVersion: deviceCanvasIpcProtocolVersion,
    port: port,
    bearerSecret: secret,
    bridgeId: "bridge-a",
    processGeneration: "pid:generation",
  );
}
