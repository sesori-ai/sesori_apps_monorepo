// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class MessageOutputLengthError {
  const MessageOutputLengthError({
    this.name = '',
    this.data = const {},
  });

  factory MessageOutputLengthError.fromJson(Map<String, dynamic> json) {
    return MessageOutputLengthError(
      name: (json["name"] ?? '') as String,
      data: (json["data"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  MessageOutputLengthError copyWith({
    String? name,
    Map<String, dynamic>? data,
  }) {
    return MessageOutputLengthError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageOutputLengthError &&
          other.name == name &&
          const DeepCollectionEquality().equals(other.data, data));

  @override
  int get hashCode => Object.hash(name, const DeepCollectionEquality().hash(data));

  final String name;
  final Map<String, dynamic> data;
}
