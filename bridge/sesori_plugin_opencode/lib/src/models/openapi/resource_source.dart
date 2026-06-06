// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_part_source.dart';
import 'file_part_source_text.dart';

class ResourceSource implements FilePartSource {
  const ResourceSource({
    required this.text,
    required this.type,
    required this.clientName,
    required this.uri,
  });

  factory ResourceSource.fromJson(Map<String, dynamic> json) {
    return ResourceSource(
      text: FilePartSourceText.fromJson(json["text"] as Map<String, dynamic>),
      type: json["type"] as String,
      clientName: json["clientName"] as String,
      uri: json["uri"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text.toJson(),
      "type": type,
      "clientName": clientName,
      "uri": uri,
    };
  }

  final FilePartSourceText text;
  final String type;
  final String clientName;
  final String uri;
}
