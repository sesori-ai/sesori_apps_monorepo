// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SessionMessageProviderState3 {
  const SessionMessageProviderState3({required this.json});
  factory SessionMessageProviderState3.fromJson(Map<String, dynamic> json) {
    return SessionMessageProviderState3(json: json);
  }
  Map<String, dynamic> toJson() => json;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageProviderState3 &&
          const DeepCollectionEquality().equals(other.json, json));

  @override
  int get hashCode => const DeepCollectionEquality().hash(json);

  final Map<String, dynamic> json;
}
