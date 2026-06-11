// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'output_format.g.dart';

@immutable
class OutputFormatText implements OutputFormat {
  const OutputFormatText();

  // ignore: avoid_unused_constructor_parameters
  factory OutputFormatText.fromJson(Map<String, dynamic> json) {
    return const OutputFormatText();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "text",
    };
  }

}
