// GENERATED FILE - DO NOT EDIT BY HAND

import 'output_format.dart';

class OutputFormatText implements OutputFormat {
  const OutputFormatText({
    required this.type,
  });

  factory OutputFormatText.fromJson(Map<String, dynamic> json) {
    return OutputFormatText(
      type: json["type"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
    };
  }

  final String type;
}
