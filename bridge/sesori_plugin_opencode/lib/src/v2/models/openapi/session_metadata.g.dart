// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SessionMetadata {
  const SessionMetadata({required this.json});
  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(json: json);
  }
  Map<String, dynamic> toJson() => json;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMetadata &&
          const DeepCollectionEquality().equals(other.json, json));

  @override
  int get hashCode => const DeepCollectionEquality().hash(json);

  final Map<String, dynamic> json;
}
