import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_provider.freezed.dart";

part "plugin_provider.g.dart";

/// The authentication mechanism required by a provider to connect.
enum PluginProviderAuthType {
  apiKey,
  oauth,
  unknown,
}

/// A model available from a provider.
@freezed
sealed class PluginModel with _$PluginModel {
  const factory PluginModel({
    required String id,
    required String name,
    String? family,
  }) = _PluginModel;
}

/// A known or custom AI provider, identified by its union variant.
///
/// Predefined variants cover the most common providers. Use [PluginProvider.custom]
/// for any provider not covered by a named variant — this allows plugin authors
/// to surface providers that the interface does not know about.
///
/// Each variant carries the provider's [id], [name], [authType], and [models].
@freezed
sealed class PluginProvider with _$PluginProvider {
  const factory PluginProvider.anthropic({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderAnthropic;

  const factory PluginProvider.openAI({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderOpenAI;

  const factory PluginProvider.google({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderGoogle;

  const factory PluginProvider.mistral({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderMistral;

  const factory PluginProvider.groq({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderGroq;

  const factory PluginProvider.xAI({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderXAI;

  const factory PluginProvider.deepseek({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderDeepseek;

  const factory PluginProvider.amazonBedrock({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderAmazonBedrock;

  const factory PluginProvider.azure({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderAzure;

  /// Catch-all for providers not covered by a named variant.
  ///
  /// Plugin authors should use this to expose providers whose IDs are not
  /// part of the predefined set.
  const factory PluginProvider.custom({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = PluginProviderCustom;
}

/// The result of [BridgePlugin.getProviders].
@freezed
sealed class PluginProvidersResult with _$PluginProvidersResult {
  const factory PluginProvidersResult({
    required List<PluginProvider> providers,
  }) = _PluginProvidersResult;
}
