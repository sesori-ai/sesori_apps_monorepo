// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class VcsApplyError {
  const VcsApplyError({
    required this.name,
    required this.data,
  });

  factory VcsApplyError.fromJson(Map<String, dynamic> json) {
    return VcsApplyError(
      name: json["name"] as String,
      data: VcsApplyErrorData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VcsApplyError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final VcsApplyErrorData data;
}

@immutable
class VcsApplyErrorData {
  const VcsApplyErrorData({
    required this.message,
    required this.reason,
  });

  factory VcsApplyErrorData.fromJson(Map<String, dynamic> json) {
    return VcsApplyErrorData(
      message: json["message"] as String,
      reason: json["reason"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "reason": reason,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VcsApplyErrorData &&
          other.message == message &&
          other.reason == reason);

  @override
  int get hashCode => Object.hash(message, reason);

  final String message;
  final String reason;
}
