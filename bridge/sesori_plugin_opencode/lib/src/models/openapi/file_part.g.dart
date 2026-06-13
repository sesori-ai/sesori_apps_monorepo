// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'file_part_source.g.dart';
import 'part.g.dart';

@immutable
class FilePart implements Part {
  const FilePart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.mime = '',
    this.filename,
    this.url = '',
    this.source,
  });

  factory FilePart.fromJson(Map<String, dynamic> json) {
    return FilePart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
      mime: (json["mime"] ?? '') as String,
      filename: json["filename"] as String?,
      url: (json["url"] ?? '') as String,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FilePart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? mime,
    String? filename,
    String? url,
    FilePartSource? source,
  }) {
    return FilePart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      mime: mime ?? this.mime,
      filename: filename ?? this.filename,
      url: url ?? this.url,
      source: source ?? this.source,
    );
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
