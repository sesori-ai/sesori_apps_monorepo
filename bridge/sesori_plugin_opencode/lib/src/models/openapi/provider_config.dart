// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class ProviderConfig {
  const ProviderConfig({
    this.api,
    this.name,
    this.env,
    this.id,
    this.npm,
    this.whitelist,
    this.blacklist,
    this.options,
    this.models,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      api: json["api"] as String?,
      name: json["name"] as String?,
      env: (json["env"] as List<dynamic>?)?.cast<String>(),
      id: json["id"] as String?,
      npm: json["npm"] as String?,
      whitelist: (json["whitelist"] as List<dynamic>?)?.cast<String>(),
      blacklist: (json["blacklist"] as List<dynamic>?)?.cast<String>(),
      options: json["options"] == null ? null : ProviderConfigOptions.fromJson(json["options"] as Map<String, dynamic>),
      models: (json["models"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, ProviderConfigModelsValue.fromJson(v as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "api": ?api,
      "name": ?name,
      "env": ?env,
      "id": ?id,
      "npm": ?npm,
      "whitelist": ?whitelist,
      "blacklist": ?blacklist,
      "options": ?options?.toJson(),
      "models": ?models?.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfig &&
          other.api == api &&
          other.name == name &&
          const DeepCollectionEquality().equals(other.env, env) &&
          other.id == id &&
          other.npm == npm &&
          const DeepCollectionEquality().equals(other.whitelist, whitelist) &&
          const DeepCollectionEquality().equals(other.blacklist, blacklist) &&
          other.options == options &&
          const DeepCollectionEquality().equals(other.models, models));

  @override
  int get hashCode => Object.hash(api, name, const DeepCollectionEquality().hash(env), id, npm, const DeepCollectionEquality().hash(whitelist), const DeepCollectionEquality().hash(blacklist), options, const DeepCollectionEquality().hash(models));

  final String? api;
  final String? name;
  final List<String>? env;
  final String? id;
  final String? npm;
  final List<String>? whitelist;
  final List<String>? blacklist;
  final ProviderConfigOptions? options;
  final Map<String, ProviderConfigModelsValue>? models;
}

@immutable
class ProviderConfigOptions {
  const ProviderConfigOptions({
    this.apiKey,
    this.baseURL,
    this.enterpriseUrl,
    this.setCacheKey,
    this.timeout,
    this.headerTimeout,
    this.chunkTimeout,
  });

  factory ProviderConfigOptions.fromJson(Map<String, dynamic> json) {
    return ProviderConfigOptions(
      apiKey: json["apiKey"] as String?,
      baseURL: json["baseURL"] as String?,
      enterpriseUrl: json["enterpriseUrl"] as String?,
      setCacheKey: json["setCacheKey"] as bool?,
      timeout: json["timeout"] as Object?,
      headerTimeout: json["headerTimeout"] as Object?,
      chunkTimeout: (json["chunkTimeout"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "apiKey": ?apiKey,
      "baseURL": ?baseURL,
      "enterpriseUrl": ?enterpriseUrl,
      "setCacheKey": ?setCacheKey,
      "timeout": ?timeout,
      "headerTimeout": ?headerTimeout,
      "chunkTimeout": ?chunkTimeout,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigOptions &&
          other.apiKey == apiKey &&
          other.baseURL == baseURL &&
          other.enterpriseUrl == enterpriseUrl &&
          other.setCacheKey == setCacheKey &&
          const DeepCollectionEquality().equals(other.timeout, timeout) &&
          const DeepCollectionEquality().equals(other.headerTimeout, headerTimeout) &&
          other.chunkTimeout == chunkTimeout);

  @override
  int get hashCode => Object.hash(apiKey, baseURL, enterpriseUrl, setCacheKey, const DeepCollectionEquality().hash(timeout), const DeepCollectionEquality().hash(headerTimeout), chunkTimeout);

  final String? apiKey;
  final String? baseURL;
  final String? enterpriseUrl;
  final bool? setCacheKey;
  final Object? timeout;
  final Object? headerTimeout;
  final int? chunkTimeout;
}

@immutable
class ProviderConfigModelsValue {
  const ProviderConfigModelsValue({
    this.id,
    this.name,
    this.family,
    this.releaseDate,
    this.attachment,
    this.reasoning,
    this.temperature,
    this.toolCall,
    this.interleaved,
    this.cost,
    this.limit,
    this.modalities,
    this.experimental,
    this.status,
    this.provider,
    this.options,
    this.headers,
    this.variants,
  });

  factory ProviderConfigModelsValue.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValue(
      id: json["id"] as String?,
      name: json["name"] as String?,
      family: json["family"] as String?,
      releaseDate: json["release_date"] as String?,
      attachment: json["attachment"] as bool?,
      reasoning: json["reasoning"] as bool?,
      temperature: json["temperature"] as bool?,
      toolCall: json["tool_call"] as bool?,
      interleaved: json["interleaved"] as Object?,
      cost: json["cost"] == null ? null : ProviderConfigModelsValueCost.fromJson(json["cost"] as Map<String, dynamic>),
      limit: json["limit"] == null ? null : ProviderConfigModelsValueLimit.fromJson(json["limit"] as Map<String, dynamic>),
      modalities: json["modalities"] == null ? null : ProviderConfigModelsValueModalities.fromJson(json["modalities"] as Map<String, dynamic>),
      experimental: json["experimental"] as bool?,
      status: json["status"] as String?,
      provider: json["provider"] == null ? null : ProviderConfigModelsValueProvider.fromJson(json["provider"] as Map<String, dynamic>),
      options: json["options"] as Map<String, dynamic>?,
      headers: (json["headers"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      variants: (json["variants"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, ProviderConfigModelsValueVariantsValue.fromJson(v as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "name": ?name,
      "family": ?family,
      "release_date": ?releaseDate,
      "attachment": ?attachment,
      "reasoning": ?reasoning,
      "temperature": ?temperature,
      "tool_call": ?toolCall,
      "interleaved": ?interleaved,
      "cost": ?cost?.toJson(),
      "limit": ?limit?.toJson(),
      "modalities": ?modalities?.toJson(),
      "experimental": ?experimental,
      "status": ?status,
      "provider": ?provider?.toJson(),
      "options": ?options,
      "headers": ?headers,
      "variants": ?variants?.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValue &&
          other.id == id &&
          other.name == name &&
          other.family == family &&
          other.releaseDate == releaseDate &&
          other.attachment == attachment &&
          other.reasoning == reasoning &&
          other.temperature == temperature &&
          other.toolCall == toolCall &&
          const DeepCollectionEquality().equals(other.interleaved, interleaved) &&
          other.cost == cost &&
          other.limit == limit &&
          other.modalities == modalities &&
          other.experimental == experimental &&
          other.status == status &&
          other.provider == provider &&
          const DeepCollectionEquality().equals(other.options, options) &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.variants, variants));

  @override
  int get hashCode => Object.hash(id, name, family, releaseDate, attachment, reasoning, temperature, toolCall, const DeepCollectionEquality().hash(interleaved), cost, limit, modalities, experimental, status, provider, const DeepCollectionEquality().hash(options), const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(variants));

  final String? id;
  final String? name;
  final String? family;
  final String? releaseDate;
  final bool? attachment;
  final bool? reasoning;
  final bool? temperature;
  final bool? toolCall;
  final Object? interleaved;
  final ProviderConfigModelsValueCost? cost;
  final ProviderConfigModelsValueLimit? limit;
  final ProviderConfigModelsValueModalities? modalities;
  final bool? experimental;
  final String? status;
  final ProviderConfigModelsValueProvider? provider;
  final Map<String, dynamic>? options;
  final Map<String, String>? headers;
  final Map<String, ProviderConfigModelsValueVariantsValue>? variants;
}

@immutable
class ProviderConfigModelsValueCost {
  const ProviderConfigModelsValueCost({
    required this.input,
    required this.output,
    this.cacheRead,
    this.cacheWrite,
    this.contextOver200k,
  });

  factory ProviderConfigModelsValueCost.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValueCost(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cacheRead: (json["cache_read"] as num?)?.toDouble(),
      cacheWrite: (json["cache_write"] as num?)?.toDouble(),
      contextOver200k: json["context_over_200k"] == null ? null : ProviderConfigModelsValueCostContextOver200k.fromJson(json["context_over_200k"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "cache_read": ?cacheRead,
      "cache_write": ?cacheWrite,
      "context_over_200k": ?contextOver200k?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValueCost &&
          other.input == input &&
          other.output == output &&
          other.cacheRead == cacheRead &&
          other.cacheWrite == cacheWrite &&
          other.contextOver200k == contextOver200k);

  @override
  int get hashCode => Object.hash(input, output, cacheRead, cacheWrite, contextOver200k);

  final double input;
  final double output;
  final double? cacheRead;
  final double? cacheWrite;
  final ProviderConfigModelsValueCostContextOver200k? contextOver200k;
}

@immutable
class ProviderConfigModelsValueLimit {
  const ProviderConfigModelsValueLimit({
    required this.context,
    this.input,
    required this.output,
  });

  factory ProviderConfigModelsValueLimit.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValueLimit(
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValueLimit &&
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
class ProviderConfigModelsValueModalities {
  const ProviderConfigModelsValueModalities({
    this.input,
    this.output,
  });

  factory ProviderConfigModelsValueModalities.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValueModalities(
      input: (json["input"] as List<dynamic>?)?.cast<String>(),
      output: (json["output"] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": ?input,
      "output": ?output,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValueModalities &&
          const DeepCollectionEquality().equals(other.input, input) &&
          const DeepCollectionEquality().equals(other.output, output));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), const DeepCollectionEquality().hash(output));

  final List<String>? input;
  final List<String>? output;
}

@immutable
class ProviderConfigModelsValueProvider {
  const ProviderConfigModelsValueProvider({
    this.npm,
    this.api,
  });

  factory ProviderConfigModelsValueProvider.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValueProvider(
      npm: json["npm"] as String?,
      api: json["api"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "npm": ?npm,
      "api": ?api,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValueProvider &&
          other.npm == npm &&
          other.api == api);

  @override
  int get hashCode => Object.hash(npm, api);

  final String? npm;
  final String? api;
}

@immutable
class ProviderConfigModelsValueVariantsValue {
  const ProviderConfigModelsValueVariantsValue({
    this.disabled,
  });

  factory ProviderConfigModelsValueVariantsValue.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValueVariantsValue(
      disabled: json["disabled"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "disabled": ?disabled,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValueVariantsValue &&
          other.disabled == disabled);

  @override
  int get hashCode => disabled.hashCode;

  final bool? disabled;
}

@immutable
class ProviderConfigModelsValueCostContextOver200k {
  const ProviderConfigModelsValueCostContextOver200k({
    required this.input,
    required this.output,
    this.cacheRead,
    this.cacheWrite,
  });

  factory ProviderConfigModelsValueCostContextOver200k.fromJson(Map<String, dynamic> json) {
    return ProviderConfigModelsValueCostContextOver200k(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cacheRead: (json["cache_read"] as num?)?.toDouble(),
      cacheWrite: (json["cache_write"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "cache_read": ?cacheRead,
      "cache_write": ?cacheWrite,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigModelsValueCostContextOver200k &&
          other.input == input &&
          other.output == output &&
          other.cacheRead == cacheRead &&
          other.cacheWrite == cacheWrite);

  @override
  int get hashCode => Object.hash(input, output, cacheRead, cacheWrite);

  final double input;
  final double output;
  final double? cacheRead;
  final double? cacheWrite;
}
