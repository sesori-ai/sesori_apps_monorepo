// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'model_capabilities.g.dart';
import 'model_compatibility.g.dart';
import 'model_cost.g.dart';
import 'model_settings.g.dart';
import 'model_variant.g.dart';

@immutable
class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.modelID,
    required this.providerID,
    required this.canonical,
    required this.family,
    required this.name,
    required this.compatibility,
    required this.package,
    required this.settings,
    required this.headers,
    required this.body,
    required this.capabilities,
    required this.variants,
    required this.time,
    required this.cost,
    required this.status,
    required this.enabled,
    required this.limit,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json["id"] as String,
      modelID: json["modelID"] as String,
      providerID: json["providerID"] as String,
      canonical: json["canonical"] as String?,
      family: json["family"] as String?,
      name: json["name"] as String,
      compatibility: json["compatibility"] == null ? null : ModelCompatibility.fromJson(json["compatibility"] as Map<String, dynamic>),
      package: json["package"] as String?,
      settings: json["settings"] == null ? null : ModelSettings.fromJson(json["settings"] as Map<String, dynamic>),
      headers: (json["headers"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>?,
      capabilities: ModelCapabilities.fromJson(json["capabilities"] as Map<String, dynamic>),
      variants: (json["variants"] as List<dynamic>).map((e) => ModelVariant.fromJson(e as Map<String, dynamic>)).toList(),
      time: ModelInfoTime.fromJson(json["time"] as Map<String, dynamic>),
      cost: (json["cost"] as List<dynamic>).map((e) => ModelCost.fromJson(e as Map<String, dynamic>)).toList(),
      status: ModelInfoStatus.fromJson(json["status"] as String),
      enabled: json["enabled"] as bool,
      limit: ModelInfoLimit.fromJson(json["limit"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "modelID": modelID,
      "providerID": providerID,
      "canonical": ?canonical,
      "family": ?family,
      "name": name,
      "compatibility": ?compatibility?.toJson(),
      "package": ?package,
      "settings": ?settings?.toJson(),
      "headers": ?headers,
      "body": ?body,
      "capabilities": capabilities.toJson(),
      "variants": variants.map((e) => e.toJson()).toList(),
      "time": time.toJson(),
      "cost": cost.map((e) => e.toJson()).toList(),
      "status": status.toJson(),
      "enabled": enabled,
      "limit": limit.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelInfo copyWith({
    String? id,
    String? modelID,
    String? providerID,
    String? canonical,
    String? family,
    String? name,
    ModelCompatibility? compatibility,
    String? package,
    ModelSettings? settings,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    ModelCapabilities? capabilities,
    List<ModelVariant>? variants,
    ModelInfoTime? time,
    List<ModelCost>? cost,
    ModelInfoStatus? status,
    bool? enabled,
    ModelInfoLimit? limit,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      modelID: modelID ?? this.modelID,
      providerID: providerID ?? this.providerID,
      canonical: canonical ?? this.canonical,
      family: family ?? this.family,
      name: name ?? this.name,
      compatibility: compatibility ?? this.compatibility,
      package: package ?? this.package,
      settings: settings ?? this.settings,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      capabilities: capabilities ?? this.capabilities,
      variants: variants ?? this.variants,
      time: time ?? this.time,
      cost: cost ?? this.cost,
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelInfo &&
          other.id == id &&
          other.modelID == modelID &&
          other.providerID == providerID &&
          other.canonical == canonical &&
          other.family == family &&
          other.name == name &&
          other.compatibility == compatibility &&
          other.package == package &&
          other.settings == settings &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body) &&
          other.capabilities == capabilities &&
          const DeepCollectionEquality().equals(other.variants, variants) &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.cost, cost) &&
          other.status == status &&
          other.enabled == enabled &&
          other.limit == limit);

  @override
  int get hashCode => Object.hash(id, modelID, providerID, canonical, family, name, compatibility, package, settings, const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body), capabilities, const DeepCollectionEquality().hash(variants), time, const DeepCollectionEquality().hash(cost), status, enabled, limit);

  final String id;
  final String modelID;
  final String providerID;
  final String? canonical;
  final String? family;
  final String name;
  final ModelCompatibility? compatibility;
  final String? package;
  final ModelSettings? settings;
  final Map<String, String>? headers;
  final Map<String, dynamic>? body;
  final ModelCapabilities capabilities;
  final List<ModelVariant> variants;
  final ModelInfoTime time;
  final List<ModelCost> cost;
  final ModelInfoStatus status;
  final bool enabled;
  final ModelInfoLimit limit;
}

@immutable
class ModelInfoTime {
  const ModelInfoTime({
    required this.released,
  });

  factory ModelInfoTime.fromJson(Map<String, dynamic> json) {
    return ModelInfoTime(
      released: (json["released"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "released": released,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelInfoTime copyWith({
    double? released,
  }) {
    return ModelInfoTime(
      released: released ?? this.released,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelInfoTime &&
          other.released == released);

  @override
  int get hashCode => released.hashCode;

  final double released;
}

@immutable
class ModelInfoLimit {
  const ModelInfoLimit({
    required this.context,
    required this.input,
    required this.output,
  });

  factory ModelInfoLimit.fromJson(Map<String, dynamic> json) {
    return ModelInfoLimit(
      context: (json["context"] as num).toInt(),
      input: (json["input"] as num?)?.toInt(),
      output: (json["output"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "context": context,
      "input": ?input,
      "output": output,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelInfoLimit copyWith({
    int? context,
    int? input,
    int? output,
  }) {
    return ModelInfoLimit(
      context: context ?? this.context,
      input: input ?? this.input,
      output: output ?? this.output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelInfoLimit &&
          other.context == context &&
          other.input == input &&
          other.output == output);

  @override
  int get hashCode => Object.hash(context, input, output);

  final int context;
  final int? input;
  final int output;
}

enum ModelInfoStatus {
  @JsonValue("alpha")
  alpha,
  @JsonValue("beta")
  beta,
  @JsonValue("deprecated")
  deprecated,
  @JsonValue("active")
  active,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ModelInfoStatus fromJson(String value) {
    switch (value) {
      case "alpha":
        return ModelInfoStatus.alpha;
      case "beta":
        return ModelInfoStatus.beta;
      case "deprecated":
        return ModelInfoStatus.deprecated;
      case "active":
        return ModelInfoStatus.active;
      default:
        return ModelInfoStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ModelInfoStatus.alpha:
        return "alpha";
      case ModelInfoStatus.beta:
        return "beta";
      case ModelInfoStatus.deprecated:
        return "deprecated";
      case ModelInfoStatus.active:
        return "active";
      case ModelInfoStatus.unknown:
        return 'unknown';
    }
  }
}
