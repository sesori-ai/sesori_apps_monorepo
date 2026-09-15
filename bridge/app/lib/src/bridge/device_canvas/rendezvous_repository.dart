import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show createHardenedDirectory, hardenPath, ownerOnlyDirectoryMode, ownerOnlyFileMode;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../server/api/runtime_file_api.dart";
import "protocol.dart";

part "rendezvous_repository.freezed.dart";
part "rendezvous_repository.g.dart";

const String deviceCanvasIpcDirectoryName = "device-canvas";
const String deviceCanvasIpcRendezvousFileName = "ipc-rendezvous.json";

@freezed
sealed class const DeviceCanvasRendezvous._() with _$DeviceCanvasRendezvous {
  const factory({
    required int protocolVersion,
    required int port,
    required String bearerSecret,
    required String bridgeId,
    required String processGeneration,
  }) = _DeviceCanvasRendezvous;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasRendezvousFromJson(json);
}

class DeviceCanvasRendezvousRepository({required final String dataDirectory}) {
  final String directoryPath = path.join(dataDirectory, deviceCanvasIpcDirectoryName);
  late final RuntimeFileApi _runtimeFileApi = RuntimeFileApi(runtimeDirectory: directoryPath);

  String get filePath => path.join(directoryPath, deviceCanvasIpcRendezvousFileName);

  Future<void> write(DeviceCanvasRendezvous rendezvous) async {
    _validate(rendezvous);
    createHardenedDirectory(directoryPath: directoryPath);
    await _runtimeFileApi.writeFile(name: deviceCanvasIpcRendezvousFileName, contents: jsonEncode(rendezvous.toJson()));
    await hardenPath(targetPath: directoryPath, mode: ownerOnlyDirectoryMode);
    await hardenPath(targetPath: filePath, mode: ownerOnlyFileMode);
  }

  Future<void> delete() async {
    await _runtimeFileApi.deleteFile(name: deviceCanvasIpcRendezvousFileName);
  }

  Future<DeviceCanvasRendezvous?> read() async {
    final contents = await _runtimeFileApi.readFile(name: deviceCanvasIpcRendezvousFileName);
    if (contents == null) return null;
    final rendezvous = DeviceCanvasRendezvous.fromJson(jsonDecodeMap(contents));
    _validate(rendezvous);
    return rendezvous;
  }

  DeviceCanvasRendezvous create({
    required int port,
    required String bearerSecret,
    required String bridgeId,
    required String processGeneration,
  }) {
    return DeviceCanvasRendezvous(
      protocolVersion: deviceCanvasIpcProtocolVersion,
      port: port,
      bearerSecret: bearerSecret,
      bridgeId: bridgeId,
      processGeneration: processGeneration,
    );
  }

  void _validate(DeviceCanvasRendezvous rendezvous) {
    if (rendezvous.protocolVersion != deviceCanvasIpcProtocolVersion) {
      throw FormatException("unsupported Device Canvas rendezvous protocol version: ${rendezvous.protocolVersion}");
    }
    if (rendezvous.port <= 0 || rendezvous.port > 65535) {
      throw FormatException("invalid Device Canvas rendezvous port: ${rendezvous.port}");
    }
    if (rendezvous.bearerSecret.isEmpty || rendezvous.bridgeId.isEmpty || rendezvous.processGeneration.isEmpty) {
      throw const FormatException("Device Canvas rendezvous contains empty required fields");
    }
  }
}
