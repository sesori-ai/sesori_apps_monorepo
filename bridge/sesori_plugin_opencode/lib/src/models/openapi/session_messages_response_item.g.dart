// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'message.g.dart';
import 'part.g.dart';

@immutable
class SessionMessagesResponseItem {
  const SessionMessagesResponseItem({
    required this.info,
    this.parts = const [],
  });

  factory SessionMessagesResponseItem.fromJson(Map<String, dynamic> json) {
    return SessionMessagesResponseItem(
      info: Message.fromJson((json["info"] ?? const <String, dynamic>{}) as Object),
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
  SessionMessagesResponseItem copyWith({
    Message? info,
    List<Part>? parts,
  }) {
    return SessionMessagesResponseItem(
      info: info ?? this.info,
      parts: parts ?? this.parts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessagesResponseItem &&
          other.info == info &&
          const DeepCollectionEquality().equals(other.parts, parts));

  @override
  int get hashCode => Object.hash(info, const DeepCollectionEquality().hash(parts));

  final Message info;
  final List<Part> parts;
}
