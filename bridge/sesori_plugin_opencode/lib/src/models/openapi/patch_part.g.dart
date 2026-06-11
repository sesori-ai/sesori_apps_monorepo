// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class PatchPart implements Part {
  const PatchPart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.hash = '',
    this.files = const [],
  });

  factory PatchPart.fromJson(Map<String, dynamic> json) {
    return PatchPart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
      hash: (json["hash"] ?? '') as String,
      files: ((json["files"] ?? const []) as List<dynamic>).cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "patch",
      "hash": hash,
      "files": files,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PatchPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? hash,
    List<String>? files,
  }) {
    return PatchPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      hash: hash ?? this.hash,
      files: files ?? this.files,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatchPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.hash == hash &&
          const DeepCollectionEquality().equals(other.files, files));

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, hash, const DeepCollectionEquality().hash(files));

  final String id;
  final String sessionID;
  final String messageID;
  final String hash;
  final List<String> files;
}
