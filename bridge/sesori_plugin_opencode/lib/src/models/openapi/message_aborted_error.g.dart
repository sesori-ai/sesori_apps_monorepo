// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class MessageAbortedError {
  const MessageAbortedError({
    this.name = '',
    required this.data,
  });

  factory MessageAbortedError.fromJson(Map<String, dynamic> json) {
    return MessageAbortedError(
      name: (json["name"] ?? '') as String,
      data: MessageAbortedErrorData.fromJson((json["data"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  MessageAbortedError copyWith({
    String? name,
    MessageAbortedErrorData? data,
  }) {
    return MessageAbortedError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageAbortedError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final MessageAbortedErrorData data;
}

@immutable
class MessageAbortedErrorData {
  const MessageAbortedErrorData({
    this.message = '',
  });

  factory MessageAbortedErrorData.fromJson(Map<String, dynamic> json) {
    return MessageAbortedErrorData(
      message: (json["message"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  MessageAbortedErrorData copyWith({
    String? message,
  }) {
    return MessageAbortedErrorData(
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageAbortedErrorData &&
          other.message == message);

  @override
  int get hashCode => message.hashCode;

  final String message;
}
