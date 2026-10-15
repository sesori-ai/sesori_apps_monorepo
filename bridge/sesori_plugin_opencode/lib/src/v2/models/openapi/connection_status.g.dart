// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';

@immutable
class ConnectionStatus {
  const ConnectionStatus({
    required this.status,
    required this.message,
    required this.url,
  });

  factory ConnectionStatus.fromJson(Map<String, dynamic> json) {
    return ConnectionStatus(
      status: json["status"] as String,
      message: json["message"] as String,
      url: json["url"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "message": message,
      "url": ?url,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ConnectionStatus copyWith({
    String? status,
    String? message,
    String? url,
  }) {
    return ConnectionStatus(
      status: status ?? this.status,
      message: message ?? this.message,
      url: url ?? this.url,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionStatus &&
          other.status == status &&
          other.message == message &&
          other.url == url);

  @override
  int get hashCode => Object.hash(status, message, url);

  final String status;
  final String message;
  final String? url;
}
