// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SessionInboxSyntheticPayload {
  const SessionInboxSyntheticPayload({
    required this.text,
    required this.description,
    required this.metadata,
  });

  factory SessionInboxSyntheticPayload.fromJson(Map<String, dynamic> json) {
    return SessionInboxSyntheticPayload(
      text: json["text"] as String,
      description: json["description"] as String?,
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text,
      "description": ?description,
      "metadata": ?metadata,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInboxSyntheticPayload copyWith({
    String? text,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return SessionInboxSyntheticPayload(
      text: text ?? this.text,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxSyntheticPayload &&
          other.text == text &&
          other.description == description &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(text, description, const DeepCollectionEquality().hash(metadata));

  final String text;
  final String? description;
  final Map<String, dynamic>? metadata;
}
