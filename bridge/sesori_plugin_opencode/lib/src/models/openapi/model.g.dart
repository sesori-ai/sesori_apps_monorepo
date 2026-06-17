// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@immutable
class Model {
  const Model({
    required this.id,
    required this.providerID,
    required this.api,
    required this.name,
    required this.family,
    required this.capabilities,
    required this.cost,
    required this.limit,
    required this.status,
    required this.options,
    required this.headers,
    required this.releaseDate,
    required this.variants,
  });

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      api: ModelApi.fromJson(json["api"] as Map<String, dynamic>),
      name: json["name"] as String,
      family: json["family"] as String?,
      capabilities: ModelCapabilities.fromJson(json["capabilities"] as Map<String, dynamic>),
      cost: ModelCost.fromJson(json["cost"] as Map<String, dynamic>),
      limit: ModelLimit.fromJson(json["limit"] as Map<String, dynamic>),
      status: ModelStatus.fromJson(json["status"] as String),
      options: json["options"] as Map<String, dynamic>,
      headers: (json["headers"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      releaseDate: json["release_date"] as String,
      variants: (json["variants"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "api": api.toJson(),
      "name": name,
      "family": ?family,
      "capabilities": capabilities.toJson(),
      "cost": cost.toJson(),
      "limit": limit.toJson(),
      "status": status.toJson(),
      "options": options,
      "headers": headers,
      "release_date": releaseDate,
      "variants": ?variants,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Model copyWith({
    String? id,
    String? providerID,
    ModelApi? api,
    String? name,
    String? family,
    ModelCapabilities? capabilities,
    ModelCost? cost,
    ModelLimit? limit,
    ModelStatus? status,
    Map<String, dynamic>? options,
    Map<String, String>? headers,
    String? releaseDate,
    Map<String, Map<String, dynamic>>? variants,
  }) {
    return Model(
      id: id ?? this.id,
      providerID: providerID ?? this.providerID,
      api: api ?? this.api,
      name: name ?? this.name,
      family: family ?? this.family,
      capabilities: capabilities ?? this.capabilities,
      cost: cost ?? this.cost,
      limit: limit ?? this.limit,
      status: status ?? this.status,
      options: options ?? this.options,
      headers: headers ?? this.headers,
      releaseDate: releaseDate ?? this.releaseDate,
      variants: variants ?? this.variants,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Model &&
          other.id == id &&
          other.providerID == providerID &&
          other.api == api &&
          other.name == name &&
          other.family == family &&
          other.capabilities == capabilities &&
          other.cost == cost &&
          other.limit == limit &&
          other.status == status &&
          const DeepCollectionEquality().equals(other.options, options) &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          other.releaseDate == releaseDate &&
          const DeepCollectionEquality().equals(other.variants, variants));

  @override
  int get hashCode => Object.hash(id, providerID, api, name, family, capabilities, cost, limit, status, const DeepCollectionEquality().hash(options), const DeepCollectionEquality().hash(headers), releaseDate, const DeepCollectionEquality().hash(variants));

  final String id;
  final String providerID;
  final ModelApi api;
  final String name;
  final String? family;
  final ModelCapabilities capabilities;
  final ModelCost cost;
  final ModelLimit limit;
  final ModelStatus status;
  final Map<String, dynamic> options;
  final Map<String, String> headers;
  final String releaseDate;
  final Map<String, Map<String, dynamic>>? variants;
}

@immutable
class ModelApi {
  const ModelApi({
    required this.id,
    required this.url,
    required this.npm,
  });

  factory ModelApi.fromJson(Map<String, dynamic> json) {
    return ModelApi(
      id: json["id"] as String,
      url: json["url"] as String,
      npm: json["npm"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "url": url,
      "npm": npm,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelApi copyWith({
    String? id,
    String? url,
    String? npm,
  }) {
    return ModelApi(
      id: id ?? this.id,
      url: url ?? this.url,
      npm: npm ?? this.npm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelApi &&
          other.id == id &&
          other.url == url &&
          other.npm == npm);

  @override
  int get hashCode => Object.hash(id, url, npm);

  final String id;
  final String url;
  final String npm;
}

@immutable
class ModelCapabilities {
  const ModelCapabilities({
    required this.temperature,
    required this.reasoning,
    required this.attachment,
    required this.toolcall,
    required this.input,
    required this.output,
    required this.interleaved,
  });

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    return ModelCapabilities(
      temperature: json["temperature"] as bool,
      reasoning: json["reasoning"] as bool,
      attachment: json["attachment"] as bool,
      toolcall: json["toolcall"] as bool,
      input: ModelCapabilitiesInput.fromJson(json["input"] as Map<String, dynamic>),
      output: ModelCapabilitiesOutput.fromJson(json["output"] as Map<String, dynamic>),
      interleaved: json["interleaved"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "temperature": temperature,
      "reasoning": reasoning,
      "attachment": attachment,
      "toolcall": toolcall,
      "input": input.toJson(),
      "output": output.toJson(),
      "interleaved": interleaved,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCapabilities copyWith({
    bool? temperature,
    bool? reasoning,
    bool? attachment,
    bool? toolcall,
    ModelCapabilitiesInput? input,
    ModelCapabilitiesOutput? output,
    Object? interleaved,
  }) {
    return ModelCapabilities(
      temperature: temperature ?? this.temperature,
      reasoning: reasoning ?? this.reasoning,
      attachment: attachment ?? this.attachment,
      toolcall: toolcall ?? this.toolcall,
      input: input ?? this.input,
      output: output ?? this.output,
      interleaved: interleaved ?? this.interleaved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapabilities &&
          other.temperature == temperature &&
          other.reasoning == reasoning &&
          other.attachment == attachment &&
          other.toolcall == toolcall &&
          other.input == input &&
          other.output == output &&
          const DeepCollectionEquality().equals(other.interleaved, interleaved));

  @override
  int get hashCode => Object.hash(temperature, reasoning, attachment, toolcall, input, output, const DeepCollectionEquality().hash(interleaved));

  final bool temperature;
  final bool reasoning;
  final bool attachment;
  final bool toolcall;
  final ModelCapabilitiesInput input;
  final ModelCapabilitiesOutput output;
  final Object interleaved;
}

@immutable
class ModelCost {
  const ModelCost({
    required this.input,
    required this.output,
    required this.cache,
    required this.tiers,
    required this.experimentalOver200K,
  });

  factory ModelCost.fromJson(Map<String, dynamic> json) {
    return ModelCost(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cache: ModelCostCache.fromJson(json["cache"] as Map<String, dynamic>),
      tiers: (json["tiers"] as List<dynamic>?)?.map((e) => ModelCostTiersItem.fromJson(e as Map<String, dynamic>)).toList(),
      experimentalOver200K: json["experimentalOver200K"] == null ? null : ModelCostExperimentalOver200K.fromJson(json["experimentalOver200K"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "cache": cache.toJson(),
      "tiers": ?tiers?.map((e) => e.toJson()).toList(),
      "experimentalOver200K": ?experimentalOver200K?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCost copyWith({
    double? input,
    double? output,
    ModelCostCache? cache,
    List<ModelCostTiersItem>? tiers,
    ModelCostExperimentalOver200K? experimentalOver200K,
  }) {
    return ModelCost(
      input: input ?? this.input,
      output: output ?? this.output,
      cache: cache ?? this.cache,
      tiers: tiers ?? this.tiers,
      experimentalOver200K: experimentalOver200K ?? this.experimentalOver200K,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCost &&
          other.input == input &&
          other.output == output &&
          other.cache == cache &&
          const DeepCollectionEquality().equals(other.tiers, tiers) &&
          other.experimentalOver200K == experimentalOver200K);

  @override
  int get hashCode => Object.hash(input, output, cache, const DeepCollectionEquality().hash(tiers), experimentalOver200K);

  final double input;
  final double output;
  final ModelCostCache cache;
  final List<ModelCostTiersItem>? tiers;
  final ModelCostExperimentalOver200K? experimentalOver200K;
}

@immutable
class ModelLimit {
  const ModelLimit({
    required this.context,
    required this.input,
    required this.output,
  });

  factory ModelLimit.fromJson(Map<String, dynamic> json) {
    return ModelLimit(
      context: (json["context"] as num).toDouble(),
      input: (json["input"] as num?)?.toDouble(),
      output: (json["output"] as num).toDouble(),
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
  ModelLimit copyWith({
    double? context,
    double? input,
    double? output,
  }) {
    return ModelLimit(
      context: context ?? this.context,
      input: input ?? this.input,
      output: output ?? this.output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelLimit &&
          other.context == context &&
          other.input == input &&
          other.output == output);

  @override
  int get hashCode => Object.hash(context, input, output);

  final double context;
  final double? input;
  final double output;
}

@immutable
class ModelCapabilitiesInput {
  const ModelCapabilitiesInput({
    required this.text,
    required this.audio,
    required this.image,
    required this.video,
    required this.pdf,
  });

  factory ModelCapabilitiesInput.fromJson(Map<String, dynamic> json) {
    return ModelCapabilitiesInput(
      text: json["text"] as bool,
      audio: json["audio"] as bool,
      image: json["image"] as bool,
      video: json["video"] as bool,
      pdf: json["pdf"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text,
      "audio": audio,
      "image": image,
      "video": video,
      "pdf": pdf,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCapabilitiesInput copyWith({
    bool? text,
    bool? audio,
    bool? image,
    bool? video,
    bool? pdf,
  }) {
    return ModelCapabilitiesInput(
      text: text ?? this.text,
      audio: audio ?? this.audio,
      image: image ?? this.image,
      video: video ?? this.video,
      pdf: pdf ?? this.pdf,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapabilitiesInput &&
          other.text == text &&
          other.audio == audio &&
          other.image == image &&
          other.video == video &&
          other.pdf == pdf);

  @override
  int get hashCode => Object.hash(text, audio, image, video, pdf);

  final bool text;
  final bool audio;
  final bool image;
  final bool video;
  final bool pdf;
}

@immutable
class ModelCapabilitiesOutput {
  const ModelCapabilitiesOutput({
    required this.text,
    required this.audio,
    required this.image,
    required this.video,
    required this.pdf,
  });

  factory ModelCapabilitiesOutput.fromJson(Map<String, dynamic> json) {
    return ModelCapabilitiesOutput(
      text: json["text"] as bool,
      audio: json["audio"] as bool,
      image: json["image"] as bool,
      video: json["video"] as bool,
      pdf: json["pdf"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text,
      "audio": audio,
      "image": image,
      "video": video,
      "pdf": pdf,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCapabilitiesOutput copyWith({
    bool? text,
    bool? audio,
    bool? image,
    bool? video,
    bool? pdf,
  }) {
    return ModelCapabilitiesOutput(
      text: text ?? this.text,
      audio: audio ?? this.audio,
      image: image ?? this.image,
      video: video ?? this.video,
      pdf: pdf ?? this.pdf,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapabilitiesOutput &&
          other.text == text &&
          other.audio == audio &&
          other.image == image &&
          other.video == video &&
          other.pdf == pdf);

  @override
  int get hashCode => Object.hash(text, audio, image, video, pdf);

  final bool text;
  final bool audio;
  final bool image;
  final bool video;
  final bool pdf;
}

@immutable
class ModelCostCache {
  const ModelCostCache({
    required this.read,
    required this.write,
  });

  factory ModelCostCache.fromJson(Map<String, dynamic> json) {
    return ModelCostCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostCache copyWith({
    double? read,
    double? write,
  }) {
    return ModelCostCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}

@immutable
class ModelCostTiersItem {
  const ModelCostTiersItem({
    required this.input,
    required this.output,
    required this.cache,
    required this.tier,
  });

  factory ModelCostTiersItem.fromJson(Map<String, dynamic> json) {
    return ModelCostTiersItem(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cache: ModelCostTiersItemCache.fromJson(json["cache"] as Map<String, dynamic>),
      tier: ModelCostTiersItemTier.fromJson(json["tier"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "cache": cache.toJson(),
      "tier": tier.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostTiersItem copyWith({
    double? input,
    double? output,
    ModelCostTiersItemCache? cache,
    ModelCostTiersItemTier? tier,
  }) {
    return ModelCostTiersItem(
      input: input ?? this.input,
      output: output ?? this.output,
      cache: cache ?? this.cache,
      tier: tier ?? this.tier,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostTiersItem &&
          other.input == input &&
          other.output == output &&
          other.cache == cache &&
          other.tier == tier);

  @override
  int get hashCode => Object.hash(input, output, cache, tier);

  final double input;
  final double output;
  final ModelCostTiersItemCache cache;
  final ModelCostTiersItemTier tier;
}

@immutable
class ModelCostExperimentalOver200K {
  const ModelCostExperimentalOver200K({
    required this.input,
    required this.output,
    required this.cache,
  });

  factory ModelCostExperimentalOver200K.fromJson(Map<String, dynamic> json) {
    return ModelCostExperimentalOver200K(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cache: ModelCostExperimentalOver200KCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "cache": cache.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostExperimentalOver200K copyWith({
    double? input,
    double? output,
    ModelCostExperimentalOver200KCache? cache,
  }) {
    return ModelCostExperimentalOver200K(
      input: input ?? this.input,
      output: output ?? this.output,
      cache: cache ?? this.cache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostExperimentalOver200K &&
          other.input == input &&
          other.output == output &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, cache);

  final double input;
  final double output;
  final ModelCostExperimentalOver200KCache cache;
}

@immutable
class ModelCostTiersItemCache {
  const ModelCostTiersItemCache({
    required this.read,
    required this.write,
  });

  factory ModelCostTiersItemCache.fromJson(Map<String, dynamic> json) {
    return ModelCostTiersItemCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostTiersItemCache copyWith({
    double? read,
    double? write,
  }) {
    return ModelCostTiersItemCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostTiersItemCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}

@immutable
class ModelCostTiersItemTier {
  const ModelCostTiersItemTier({
    required this.type,
    required this.size,
  });

  factory ModelCostTiersItemTier.fromJson(Map<String, dynamic> json) {
    return ModelCostTiersItemTier(
      type: json["type"] as String,
      size: (json["size"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "size": size,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostTiersItemTier copyWith({
    String? type,
    double? size,
  }) {
    return ModelCostTiersItemTier(
      type: type ?? this.type,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostTiersItemTier &&
          other.type == type &&
          other.size == size);

  @override
  int get hashCode => Object.hash(type, size);

  final String type;
  final double size;
}

@immutable
class ModelCostExperimentalOver200KCache {
  const ModelCostExperimentalOver200KCache({
    required this.read,
    required this.write,
  });

  factory ModelCostExperimentalOver200KCache.fromJson(Map<String, dynamic> json) {
    return ModelCostExperimentalOver200KCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostExperimentalOver200KCache copyWith({
    double? read,
    double? write,
  }) {
    return ModelCostExperimentalOver200KCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostExperimentalOver200KCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}

enum ModelStatus {
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

  static ModelStatus fromJson(String value) {
    switch (value) {
      case "alpha":
        return ModelStatus.alpha;
      case "beta":
        return ModelStatus.beta;
      case "deprecated":
        return ModelStatus.deprecated;
      case "active":
        return ModelStatus.active;
      default:
        return ModelStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ModelStatus.alpha:
        return "alpha";
      case ModelStatus.beta:
        return "beta";
      case ModelStatus.deprecated:
        return "deprecated";
      case ModelStatus.active:
        return "active";
      case ModelStatus.unknown:
        return 'unknown';
    }
  }
}
