// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

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
