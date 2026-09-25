// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class SessionInboxCompactionPayload {
  const SessionInboxCompactionPayload();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionInboxCompactionPayload.fromJson(Object json) {
    if (json is Map<String, dynamic>) {
      return SessionInboxCompactionPayload00Inline.fromJson(json);
    }
    if (json is List) {
      return SessionInboxCompactionPayload01Inline.fromJson(json as List<dynamic>);
    }
    return SessionInboxCompactionPayloadUnknown(raw: json);
  }
}

@immutable
class SessionInboxCompactionPayload00Inline implements SessionInboxCompactionPayload {
  const SessionInboxCompactionPayload00Inline({required this.json});
  factory SessionInboxCompactionPayload00Inline.fromJson(Map<String, dynamic> json) {
    return SessionInboxCompactionPayload00Inline(json: json);
  }
  @override
  Map<String, dynamic> toJson() => json;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxCompactionPayload00Inline &&
          const DeepCollectionEquality().equals(other.json, json));

  @override
  int get hashCode => const DeepCollectionEquality().hash(json);

  final Map<String, dynamic> json;
}


@immutable
class SessionInboxCompactionPayload01Inline implements SessionInboxCompactionPayload {
  const SessionInboxCompactionPayload01Inline({required this.items});
  factory SessionInboxCompactionPayload01Inline.fromJson(List<dynamic> json) {
    return SessionInboxCompactionPayload01Inline(items: json.cast<Object>());
  }
  @override
  Object? toJson() => items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxCompactionPayload01Inline &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<Object> items;
}


/// Fallback variant for an unrecognized [SessionInboxCompactionPayload] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionInboxCompactionPayloadUnknown implements SessionInboxCompactionPayload {
  const SessionInboxCompactionPayloadUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxCompactionPayloadUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
