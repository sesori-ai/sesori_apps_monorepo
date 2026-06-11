// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class ModelV2Info {
  const ModelV2Info({
    required this.id,
    required this.providerID,
    this.family,
    required this.name,
    required this.api,
    required this.capabilities,
    required this.request,
    required this.variants,
    required this.time,
    required this.cost,
    required this.status,
    required this.enabled,
    required this.limit,
  });

  factory ModelV2Info.fromJson(Map<String, dynamic> json) {
    return ModelV2Info(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      family: json["family"] as String?,
      name: json["name"] as String,
      api: json["api"] as Object,
      capabilities: ModelV2InfoCapabilities.fromJson(json["capabilities"] as Map<String, dynamic>),
      request: ModelV2InfoRequest.fromJson(json["request"] as Map<String, dynamic>),
      variants: (json["variants"] as List<dynamic>).map((e) => ModelV2InfoVariantsItem.fromJson(e as Map<String, dynamic>)).toList(),
      time: ModelV2InfoTime.fromJson(json["time"] as Map<String, dynamic>),
      cost: (json["cost"] as List<dynamic>).map((e) => ModelV2InfoCostItem.fromJson(e as Map<String, dynamic>)).toList(),
      status: json["status"] as String,
      enabled: json["enabled"] as bool,
      limit: ModelV2InfoLimit.fromJson(json["limit"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "family": ?family,
      "name": name,
      "api": api,
      "capabilities": capabilities.toJson(),
      "request": request.toJson(),
      "variants": variants.map((e) => e.toJson()).toList(),
      "time": time.toJson(),
      "cost": cost.map((e) => e.toJson()).toList(),
      "status": status,
      "enabled": enabled,
      "limit": limit.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2Info &&
          other.id == id &&
          other.providerID == providerID &&
          other.family == family &&
          other.name == name &&
          const DeepCollectionEquality().equals(other.api, api) &&
          other.capabilities == capabilities &&
          other.request == request &&
          const DeepCollectionEquality().equals(other.variants, variants) &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.cost, cost) &&
          other.status == status &&
          other.enabled == enabled &&
          other.limit == limit);

  @override
  int get hashCode => Object.hash(id, providerID, family, name, const DeepCollectionEquality().hash(api), capabilities, request, const DeepCollectionEquality().hash(variants), time, const DeepCollectionEquality().hash(cost), status, enabled, limit);

  final String id;
  final String providerID;
  final String? family;
  final String name;
  final Object api;
  final ModelV2InfoCapabilities capabilities;
  final ModelV2InfoRequest request;
  final List<ModelV2InfoVariantsItem> variants;
  final ModelV2InfoTime time;
  final List<ModelV2InfoCostItem> cost;
  final String status;
  final bool enabled;
  final ModelV2InfoLimit limit;
}

@immutable
class ModelV2InfoCapabilities {
  const ModelV2InfoCapabilities({
    required this.tools,
    required this.input,
    required this.output,
  });

  factory ModelV2InfoCapabilities.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoCapabilities(
      tools: json["tools"] as bool,
      input: (json["input"] as List<dynamic>).cast<String>(),
      output: (json["output"] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "tools": tools,
      "input": input,
      "output": output,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoCapabilities &&
          other.tools == tools &&
          const DeepCollectionEquality().equals(other.input, input) &&
          const DeepCollectionEquality().equals(other.output, output));

  @override
  int get hashCode => Object.hash(tools, const DeepCollectionEquality().hash(input), const DeepCollectionEquality().hash(output));

  final bool tools;
  final List<String> input;
  final List<String> output;
}

@immutable
class ModelV2InfoRequest {
  const ModelV2InfoRequest({
    required this.headers,
    required this.body,
    this.variant,
  });

  factory ModelV2InfoRequest.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoRequest(
      headers: (json["headers"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "headers": headers,
      "body": body,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoRequest &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body) &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body), variant);

  final Map<String, String> headers;
  final Map<String, dynamic> body;
  final String? variant;
}

@immutable
class ModelV2InfoVariantsItem {
  const ModelV2InfoVariantsItem({
    required this.id,
    required this.headers,
    required this.body,
  });

  factory ModelV2InfoVariantsItem.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoVariantsItem(
      id: json["id"] as String,
      headers: (json["headers"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "headers": headers,
      "body": body,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoVariantsItem &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body));

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body));

  final String id;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}

@immutable
class ModelV2InfoTime {
  const ModelV2InfoTime({
    required this.released,
  });

  factory ModelV2InfoTime.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoTime(
      released: json["released"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "released": released,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoTime &&
          const DeepCollectionEquality().equals(other.released, released));

  @override
  int get hashCode => const DeepCollectionEquality().hash(released);

  final Object released;
}

@immutable
class ModelV2InfoCostItem {
  const ModelV2InfoCostItem({
    this.tier,
    required this.input,
    required this.output,
    required this.cache,
  });

  factory ModelV2InfoCostItem.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoCostItem(
      tier: json["tier"] == null ? null : ModelV2InfoCostItemTier.fromJson(json["tier"] as Map<String, dynamic>),
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cache: ModelV2InfoCostItemCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "tier": ?tier?.toJson(),
      "input": input,
      "output": output,
      "cache": cache.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoCostItem &&
          other.tier == tier &&
          other.input == input &&
          other.output == output &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(tier, input, output, cache);

  final ModelV2InfoCostItemTier? tier;
  final double input;
  final double output;
  final ModelV2InfoCostItemCache cache;
}

@immutable
class ModelV2InfoLimit {
  const ModelV2InfoLimit({
    required this.context,
    this.input,
    required this.output,
  });

  factory ModelV2InfoLimit.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoLimit(
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoLimit &&
          other.context == context &&
          other.input == input &&
          other.output == output);

  @override
  int get hashCode => Object.hash(context, input, output);

  final int context;
  final int? input;
  final int output;
}

@immutable
class ModelV2InfoCostItemTier {
  const ModelV2InfoCostItemTier({
    required this.type,
    required this.size,
  });

  factory ModelV2InfoCostItemTier.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoCostItemTier(
      type: json["type"] as String,
      size: (json["size"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "size": size,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoCostItemTier &&
          other.type == type &&
          other.size == size);

  @override
  int get hashCode => Object.hash(type, size);

  final String type;
  final int size;
}

@immutable
class ModelV2InfoCostItemCache {
  const ModelV2InfoCostItemCache({
    required this.read,
    required this.write,
  });

  factory ModelV2InfoCostItemCache.fromJson(Map<String, dynamic> json) {
    return ModelV2InfoCostItemCache(
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelV2InfoCostItemCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
