// ignore_for_file: no_slop_linter/prefer_required_named_parameters
import "dart:async";
import "dart:io";

import "api_response.dart";

enum HttpMethod {
  get("GET"),
  post("POST"),
  patch("PATCH"),
  delete("DELETE"),
  ;

  final String dioName;

  const HttpMethod(this.dioName);
}

abstract class SafeApiClient {
  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> get<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    final ContentType? contentType,
    final bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> post<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    required final Object? body,
    final ContentType? contentType,
    final bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> patch<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    required final Object? body,
    final ContentType? contentType,
    final bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> delete<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    final ContentType? contentType,
    final bool logBody,
  });
}
