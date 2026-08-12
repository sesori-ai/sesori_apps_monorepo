// ignore_for_file: no_slop_linter/prefer_required_named_parameters
import "dart:async";
import "dart:io";

import "api_response.dart";

enum HttpMethod {
  get("GET"),
  post("POST"),
  put("PUT"),
  patch("PATCH"),
  delete("DELETE"),
  ;

  final String dioName;

  HttpMethod(this.dioName);
}

abstract class SafeApiClient {
  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> get<T>(
    Uri url, {
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    ContentType? contentType,
    bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> post<T>(
    Uri url, {
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    // ignore: no_slop_linter/prefer_specific_type
    required Object? body,
    ContentType? contentType,
    bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> put<T>({
    required Uri url,
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    required Map<String, String>? headers,
    // ignore: no_slop_linter/prefer_specific_type
    required Object? body,
    required ContentType? contentType,
    required bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> patch<T>(
    Uri url, {
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    // ignore: no_slop_linter/prefer_specific_type
    required Object? body,
    ContentType? contentType,
    bool logBody,
  });

  /// If [contentType] is null, [ContentType.json] will be used.
  Future<ApiResponse<T>> delete<T>(
    Uri url, {
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    ContentType? contentType,
    bool logBody,
  });
}
