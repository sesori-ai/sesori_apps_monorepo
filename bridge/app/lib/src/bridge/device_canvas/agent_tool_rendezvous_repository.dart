import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show writeRestrictedFile;

import "agent_tool_protocol.dart";

const String deviceCanvasAgentToolRendezvousFileName = "device-canvas-agent-tools.json";

String deviceCanvasAgentToolRendezvousPath({required String dataDirectory}) =>
    path.join(dataDirectory, deviceCanvasAgentToolRendezvousFileName);

class DeviceCanvasAgentToolRendezvousRepository({required final String filePath}) {
  final String _filePath = filePath;

  Future<void> publish(DeviceCanvasAgentToolRendezvous rendezvous) {
    return writeRestrictedFile(filePath: _filePath, contents: jsonEncode(rendezvous.toJson()));
  }

  Future<void> remove() async {
    final file = File(_filePath);
    try {
      await file.delete();
    } on FileSystemException {
      if (file.existsSync()) rethrow;
    }
  }
}
