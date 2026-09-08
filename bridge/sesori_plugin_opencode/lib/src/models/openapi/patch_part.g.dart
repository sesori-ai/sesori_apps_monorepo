// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class PatchPart implements Part {
  const PatchPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.hash,
    required this.files,
  });

  factory PatchPart.fromJson(Map<String, dynamic> json) {
    return PatchPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      hash: json["hash"] as String,
      files: (json["files"] as List<dynamic>).cast<String>(),
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
