// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';

@immutable
class SessionInterruptResponse {
  const SessionInterruptResponse({
    required this.interrupted,
  });

  factory SessionInterruptResponse.fromJson(Map<String, dynamic> json) {
    return SessionInterruptResponse(
      interrupted: json["interrupted"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "interrupted": interrupted,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInterruptResponse copyWith({
    bool? interrupted,
  }) {
    return SessionInterruptResponse(
      interrupted: interrupted ?? this.interrupted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SessionInterruptResponse && other.interrupted == interrupted);

  @override
  int get hashCode => interrupted.hashCode;

  final bool interrupted;
}
