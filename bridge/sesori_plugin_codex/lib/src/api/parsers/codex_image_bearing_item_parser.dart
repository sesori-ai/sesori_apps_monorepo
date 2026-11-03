import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/codex_image_bearing_item_dto.dart";

/// Parses app-server items that can carry image content: generated images
/// and image results of MCP and dynamic tool calls.
class const CodexImageBearingItemParser() {
  CodexImageBearingItemDto? parse({required Map<String, dynamic> item}) {
    try {
      return CodexImageBearingItemDto.fromJson(item);
    } on Object catch (error, stackTrace) {
      Log.w("[codex] skipping malformed image-bearing app-server item", error, stackTrace);
      return null;
    }
  }
}
