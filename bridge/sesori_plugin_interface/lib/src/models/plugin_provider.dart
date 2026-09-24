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

    /// Effort/thinking variants in the order pickers list them.
    required List<String> variants,

    /// The variant a session runs at when none was chosen. Null means the
    /// first of [variants], or nothing when the model offers none.
    String? defaultVariant,
    String? family,
    @Default(true) bool isAvailable,
    DateTime? releaseDate,

    /// The model's fast mode, or null when the model has none.
    required PluginFastModeSupport? fastMode,
  }) = _PluginModel;
}

/// Whether a model's fast mode can run for the current account.
@freezed
sealed class PluginFastModeSupport with _$PluginFastModeSupport {
  /// Fast mode can run. [promptCacheTtlSeconds] is how long the backend keeps
  /// the prompt cache that a fast-mode switch drops.
  const factory available({required int promptCacheTtlSeconds}) = PluginFastModeAvailable;

  /// The model has fast mode, but the account cannot use it right now.
  const factory unavailable({required PluginFastModeUnavailableReason reason}) = PluginFastModeUnavailable;
}

/// Why an account cannot use a model's fast mode.
enum PluginFastModeUnavailableReason() {
  /// The account has extra usage turned off, which fast mode bills against.
  extraUsageDisabled,

  /// The account's plan does not include fast mode.
  notOnPlan,

  /// An organization policy turned fast mode or its model off.
  disabledByOrganization,
  unknown,
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
