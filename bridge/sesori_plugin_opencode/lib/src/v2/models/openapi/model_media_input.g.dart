// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

import 'package:json_annotation/json_annotation.dart';

enum ModelMediaInput {
  @JsonValue("assets")
  assets,
  @JsonValue("state")
  state,
  @JsonValue("root")
  root,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ModelMediaInput fromJson(String value) {
    switch (value) {
      case "assets":
        return ModelMediaInput.assets;
      case "state":
        return ModelMediaInput.state;
      case "root":
        return ModelMediaInput.root;
      default:
        return ModelMediaInput.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ModelMediaInput.assets:
        return "assets";
      case ModelMediaInput.state:
        return "state";
      case ModelMediaInput.root:
        return "root";
      case ModelMediaInput.unknown:
        return 'unknown';
    }
  }
}
