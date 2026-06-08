// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.630555Z

import 'file_part_source.dart';
import 'file_part_source_text.dart';

class ResourceSource implements FilePartSource {
  const ResourceSource({
    required this.text,
    required this.clientName,
    required this.uri,
  });

  factory ResourceSource.fromJson(Map<String, dynamic> json) {
    return ResourceSource(
      text: FilePartSourceText.fromJson(json["text"] as Map<String, dynamic>),
      clientName: json["clientName"] as String,
      uri: json["uri"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text.toJson(),
      "type": "resource",
      "clientName": clientName,
      "uri": uri,
    };
  }

  final FilePartSourceText text;
  final String clientName;
  final String uri;
}
