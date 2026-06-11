// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class ProviderV2Info {
  const ProviderV2Info({
    required this.id,
    required this.name,
    required this.enabled,
    required this.env,
    required this.api,
    required this.request,
  });

  factory ProviderV2Info.fromJson(Map<String, dynamic> json) {
    return ProviderV2Info(
      id: json["id"] as String,
      name: json["name"] as String,
      enabled: json["enabled"] as Object,
      env: (json["env"] as List<dynamic>).cast<String>(),
      api: json["api"] as Object,
      request: ProviderV2InfoRequest.fromJson(json["request"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "enabled": enabled,
      "env": env,
      "api": api,
      "request": request.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderV2Info &&
          other.id == id &&
          other.name == name &&
          const DeepCollectionEquality().equals(other.enabled, enabled) &&
          const DeepCollectionEquality().equals(other.env, env) &&
          const DeepCollectionEquality().equals(other.api, api) &&
          other.request == request);

  @override
  int get hashCode => Object.hash(id, name, const DeepCollectionEquality().hash(enabled), const DeepCollectionEquality().hash(env), const DeepCollectionEquality().hash(api), request);

  final String id;
  final String name;
  final Object enabled;
  final List<String> env;
  final Object api;
  final ProviderV2InfoRequest request;
}

@immutable
class ProviderV2InfoRequest {
  const ProviderV2InfoRequest({
    required this.headers,
    required this.body,
  });

  factory ProviderV2InfoRequest.fromJson(Map<String, dynamic> json) {
    return ProviderV2InfoRequest(
      headers: (json["headers"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "headers": headers,
      "body": body,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderV2InfoRequest &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body));

  final Map<String, String> headers;
  final Map<String, dynamic> body;
}
