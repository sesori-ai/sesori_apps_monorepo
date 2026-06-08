// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.977463Z

import 'package:meta/meta.dart';
import 'part.dart';

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatchPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.hash == hash &&
          other.files == files);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, hash, files);

  final String id;
  final String sessionID;
  final String messageID;
  final String hash;
  final List<String> files;
}
