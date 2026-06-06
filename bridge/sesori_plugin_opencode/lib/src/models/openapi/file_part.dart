// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_part_source.dart';
import 'part.dart';

class FilePart implements Part {
  const FilePart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
    required this.mime,
    this.filename,
    required this.url,
    this.source,
  });

  factory FilePart.fromJson(Map<String, dynamic> json) {
    return FilePart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      type: json["type"] as String,
      mime: json["mime"] as String,
      filename: json["filename"] as String?,
      url: json["url"] as String,
      source: json["source"] == null ? null : FilePartSource.fromJson(json["source"]),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": type,
      "mime": mime,
      "filename": filename,
      "url": url,
      "source": source?.toJson(),
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String type;
  final String mime;
  final String? filename;
  final String url;
  final FilePartSource? source;
}
