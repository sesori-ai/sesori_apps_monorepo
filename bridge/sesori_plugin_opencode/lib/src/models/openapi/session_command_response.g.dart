// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'assistant_message.g.dart';
import 'part.g.dart';

@immutable
class SessionCommandResponse {
  const SessionCommandResponse({
    required this.info,
    this.parts = const [],
  });

  factory SessionCommandResponse.fromJson(Map<String, dynamic> json) {
    return SessionCommandResponse(
      info: AssistantMessage.fromJson((json["info"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
      parts: ((json["parts"] ?? const []) as List<dynamic>).map((e) => Part.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "info": info.toJson(),
      "parts": parts.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionCommandResponse copyWith({
    AssistantMessage? info,
    List<Part>? parts,
  }) {
    return SessionCommandResponse(
      info: info ?? this.info,
      parts: parts ?? this.parts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionCommandResponse &&
          other.info == info &&
          const DeepCollectionEquality().equals(other.parts, parts));

  @override
  int get hashCode => Object.hash(info, const DeepCollectionEquality().hash(parts));

  final AssistantMessage info;
  final List<Part> parts;
}
