// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SessionMessageProviderState {
  const SessionMessageProviderState({required this.json});
  factory SessionMessageProviderState.fromJson(Map<String, dynamic> json) {
    return SessionMessageProviderState(json: json);
  }
  Map<String, dynamic> toJson() => json;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageProviderState &&
          const DeepCollectionEquality().equals(other.json, json));

  @override
  int get hashCode => const DeepCollectionEquality().hash(json);

  final Map<String, dynamic> json;
}
