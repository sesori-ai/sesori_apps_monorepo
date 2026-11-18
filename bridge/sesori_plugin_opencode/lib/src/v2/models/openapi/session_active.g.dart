// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:meta/meta.dart';

@immutable
class SessionActive {
  const SessionActive({
    required this.type,
  });

  factory SessionActive.fromJson(Map<String, dynamic> json) {
    return SessionActive(
      type: json["type"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionActive copyWith({
    String? type,
  }) {
    return SessionActive(
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionActive &&
          other.type == type);

  @override
  int get hashCode => type.hashCode;

  final String type;
}
