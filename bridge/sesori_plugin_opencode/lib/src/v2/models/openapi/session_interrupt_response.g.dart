// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

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
      identical(this, other) ||
      (other is SessionInterruptResponse &&
          other.interrupted == interrupted);

  @override
  int get hashCode => interrupted.hashCode;

  final bool interrupted;
}
