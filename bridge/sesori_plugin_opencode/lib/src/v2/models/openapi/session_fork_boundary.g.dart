// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class SessionForkBoundary {
  const SessionForkBoundary();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionForkBoundary.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "before":
        return SessionForkBoundaryBefore.fromJson(map);
      case "through":
        return SessionForkBoundaryThrough.fromJson(map);
      default:
        return SessionForkBoundaryUnknown(raw: map);
    }
  }
}

@immutable
class SessionForkBoundaryBefore implements SessionForkBoundary {
  const SessionForkBoundaryBefore({
    required this.messageID,
  });

  factory SessionForkBoundaryBefore.fromJson(Map<String, dynamic> json) {
    return SessionForkBoundaryBefore(
      messageID: json["messageID"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "before",
      "messageID": messageID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionForkBoundaryBefore copyWith({
    String? messageID,
  }) {
    return SessionForkBoundaryBefore(
      messageID: messageID ?? this.messageID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionForkBoundaryBefore &&
          other.messageID == messageID);

  @override
  int get hashCode => messageID.hashCode;

  final String messageID;
}


@immutable
class SessionForkBoundaryThrough implements SessionForkBoundary {
  const SessionForkBoundaryThrough({
    required this.messageID,
  });

  factory SessionForkBoundaryThrough.fromJson(Map<String, dynamic> json) {
    return SessionForkBoundaryThrough(
      messageID: json["messageID"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "through",
      "messageID": messageID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionForkBoundaryThrough copyWith({
    String? messageID,
  }) {
    return SessionForkBoundaryThrough(
      messageID: messageID ?? this.messageID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionForkBoundaryThrough &&
          other.messageID == messageID);

  @override
  int get hashCode => messageID.hashCode;

  final String messageID;
}


/// Fallback variant for an unrecognized [SessionForkBoundary] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionForkBoundaryUnknown implements SessionForkBoundary {
  const SessionForkBoundaryUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionForkBoundaryUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
