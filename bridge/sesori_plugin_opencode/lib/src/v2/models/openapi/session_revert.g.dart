// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'file_diff_info.g.dart';

@immutable
class SessionRevert {
  const SessionRevert({
    required this.messageID,
    required this.partID,
    required this.snapshot,
    required this.files,
  });

  factory SessionRevert.fromJson(Map<String, dynamic> json) {
    return SessionRevert(
      messageID: json["messageID"] as String,
      partID: json["partID"] as String?,
      snapshot: json["snapshot"] as String?,
      files: (json["files"] as List<dynamic>?)?.map((e) => FileDiffInfo.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "messageID": messageID,
      "partID": ?partID,
      "snapshot": ?snapshot,
      "files": ?files?.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionRevert copyWith({
    String? messageID,
    String? partID,
    String? snapshot,
    List<FileDiffInfo>? files,
  }) {
    return SessionRevert(
      messageID: messageID ?? this.messageID,
      partID: partID ?? this.partID,
      snapshot: snapshot ?? this.snapshot,
      files: files ?? this.files,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRevert &&
          other.messageID == messageID &&
          other.partID == partID &&
          other.snapshot == snapshot &&
          const DeepCollectionEquality().equals(other.files, files));

  @override
  int get hashCode => Object.hash(messageID, partID, snapshot, const DeepCollectionEquality().hash(files));

  final String messageID;
  final String? partID;
  final String? snapshot;
  final List<FileDiffInfo>? files;
}
