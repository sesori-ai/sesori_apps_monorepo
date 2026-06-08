// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.935527Z

import 'package:meta/meta.dart';
import 'file_part_source.dart';
import 'part.dart';

@immutable
class FilePart implements Part {
  const FilePart({
    required this.id,
    required this.sessionID,
    required this.messageID,
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
      mime: json["mime"] as String,
      filename: json["filename"] as String?,
      url: json["url"] as String,
      source: json["source"] == null ? null : FilePartSource.fromJson(json["source"] as Object),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "file",
      "mime": mime,
      "filename": ?filename,
      "url": url,
      "source": ?source?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilePart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.mime == mime &&
          other.filename == filename &&
          other.url == url &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, mime, filename, url, source);

  final String id;
  final String sessionID;
  final String messageID;
  final String mime;
  final String? filename;
  final String url;
  final FilePartSource? source;
}
