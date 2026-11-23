// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

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
