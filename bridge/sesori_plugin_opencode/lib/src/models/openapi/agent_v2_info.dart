// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'permission_v2_ruleset.dart';

@immutable
class AgentV2Info {
  const AgentV2Info({
    required this.id,
    this.model,
    required this.request,
    this.system,
    this.description,
    required this.mode,
    required this.hidden,
    this.color,
    this.steps,
    required this.permissions,
  });

  factory AgentV2Info.fromJson(Map<String, dynamic> json) {
    return AgentV2Info(
      id: json["id"] as String,
      model: json["model"] == null ? null : AgentV2InfoModel.fromJson(json["model"] as Map<String, dynamic>),
      request: AgentV2InfoRequest.fromJson(json["request"] as Map<String, dynamic>),
      system: json["system"] as String?,
      description: json["description"] as String?,
      mode: json["mode"] as String,
      hidden: json["hidden"] as bool,
      color: json["color"] as Object?,
      steps: (json["steps"] as num?)?.toInt(),
      permissions: PermissionV2Ruleset.fromJson(json["permissions"] as List<dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "model": ?model?.toJson(),
      "request": request.toJson(),
      "system": ?system,
      "description": ?description,
      "mode": mode,
      "hidden": hidden,
      "color": ?color,
      "steps": ?steps,
      "permissions": permissions.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentV2Info &&
          other.id == id &&
          other.model == model &&
          other.request == request &&
          other.system == system &&
          other.description == description &&
          other.mode == mode &&
          other.hidden == hidden &&
          const DeepCollectionEquality().equals(other.color, color) &&
          other.steps == steps &&
          other.permissions == permissions);

  @override
  int get hashCode => Object.hash(id, model, request, system, description, mode, hidden, const DeepCollectionEquality().hash(color), steps, permissions);

  final String id;
  final AgentV2InfoModel? model;
  final AgentV2InfoRequest request;
  final String? system;
  final String? description;
  final String mode;
  final bool hidden;
  final Object? color;
  final int? steps;
  final PermissionV2Ruleset permissions;
}

@immutable
class AgentV2InfoModel {
  const AgentV2InfoModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory AgentV2InfoModel.fromJson(Map<String, dynamic> json) {
    return AgentV2InfoModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentV2InfoModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}

@immutable
class AgentV2InfoRequest {
  const AgentV2InfoRequest({
    required this.headers,
    required this.body,
  });

  factory AgentV2InfoRequest.fromJson(Map<String, dynamic> json) {
    return AgentV2InfoRequest(
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
      (other is AgentV2InfoRequest &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body));

  final Map<String, String> headers;
  final Map<String, dynamic> body;
}
