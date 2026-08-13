import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/codex_image_bearing_item_dto.dart";

/// Parses app-server items that can carry generated image content.
///
/// This boundary retains typed image/audio fields for later mapping while
/// exposing only existing text behavior to consumers in this step.
class const CodexImageBearingItemParser() {
  CodexImageBearingItemDto? parse({required Map<String, dynamic> item}) {
    try {
      return CodexImageBearingItemDto.fromJson(item);
    } on Object {
      Log.w("[codex] skipping malformed image-bearing app-server item");
      return null;
    }
  }
}
