import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_provider.freezed.dart";

part "plugin_provider.g.dart";

/// The authentication mechanism required by a provider to connect.
enum PluginProviderAuthType() {
  apiKey,
  oauth,
  unknown,
}

/// A model available from a provider.
@freezed
sealed class PluginModel with _$PluginModel {
  // ignore: no_slop_linter/prefer_required_named_parameters, generated public model signature
  const factory({
    required String id,
    required String name,
    required List<String> variants,
    String? family,
    @Default(true) bool isAvailable,
    DateTime? releaseDate,
  }) = _PluginModel;
}

/// An AI provider available from a plugin.
@freezed
sealed class PluginProvider with _$PluginProvider {
  const factory({
    required String id,
    required String name,
    required PluginProviderAuthType authType,
    required List<PluginModel> models,
    required String? defaultModelID,
  }) = _PluginProvider;
}

/// The result of [BridgePlugin.getProviders].
@freezed
sealed class PluginProvidersResult with _$PluginProvidersResult {
  const factory({
    required List<PluginProvider> providers,
  }) = _PluginProvidersResult;
}
