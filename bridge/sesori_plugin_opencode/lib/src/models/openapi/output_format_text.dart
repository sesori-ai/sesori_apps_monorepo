// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.944493Z

import 'package:meta/meta.dart';
import 'output_format.dart';

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
