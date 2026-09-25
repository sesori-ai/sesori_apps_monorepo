// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class PermissionSource {
  const PermissionSource();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory PermissionSource.fromJson(Object json) {
    if (json is Map<String, dynamic> && json["type"] == "tool") {
      return PermissionSource00Inline.fromJson(json);
    }
    return PermissionSourceUnknown(raw: json);
  }
}

@immutable
class PermissionSource00Inline implements PermissionSource {
  const PermissionSource00Inline({
    required this.messageID,
    required this.id,
  });

  factory PermissionSource00Inline.fromJson(Map<String, dynamic> json) {
    return PermissionSource00Inline(
      messageID: json["messageID"] as String,
      id: json["id"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "tool",
      "messageID": messageID,
      "id": id,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PermissionSource00Inline copyWith({
    String? messageID,
    String? id,
  }) {
    return PermissionSource00Inline(
      messageID: messageID ?? this.messageID,
      id: id ?? this.id,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionSource00Inline &&
          other.messageID == messageID &&
          other.id == id);

  @override
  int get hashCode => Object.hash(messageID, id);

  final String messageID;
  final String id;
}


/// Fallback variant for an unrecognized [PermissionSource] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class PermissionSourceUnknown implements PermissionSource {
  const PermissionSourceUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionSourceUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
