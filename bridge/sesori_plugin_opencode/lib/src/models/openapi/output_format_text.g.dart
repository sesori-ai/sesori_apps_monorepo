// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

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
