import "package:freezed_annotation/freezed_annotation.dart";

import "../../converters/date_converter.dart";

part "provider_info.freezed.dart";

part "provider_info.g.dart";

/// Represents an available provider from `GET /provider`.
///
/// We only model the fields relevant for the mobile picker UI.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderInfo with _$ProviderInfo {
  const factory({
    required String id,
    required String name,
    required Map<String, ProviderModel> models,
    required String? defaultModelID,
  }) = _ProviderInfo;

  factory fromJson(Map<String, dynamic> json) => _$ProviderInfoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProviderModel with _$ProviderModel {
  const factory({
    required String id,
    required String providerID,
    required String name,

    /// Effort/thinking variants in the order pickers list them.
    required List<String> variants,

    /// The variant a session runs at when none was chosen. Null means the
    /// first of [variants], or nothing when the model offers none.
    required String? defaultVariant,
    required String? family,
    @Default(true) bool isAvailable,

    /// The model's fast mode, or null when the model has none.
    // COMPATIBILITY 2026-09-24 (v1.9.0): Bridges before fast mode omit fastMode, which reads as null and honestly means no fast mode is offered. Retire this note once the minimum supported bridge always sends the field.
    required FastModeSupport? fastMode,
    @dateConverter required DateTime? releaseDate,
  }) = _ProviderModel;

  factory fromJson(Map<String, dynamic> json) => _$ProviderModelFromJson(json);
}

/// Whether a model's fast mode can run for the current account.
@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: true)
sealed class FastModeSupport with _$FastModeSupport {
  /// Fast mode can run. [promptCacheTtlSeconds] is how long the backend keeps
  /// the prompt cache that a fast-mode switch drops.
  const factory available({required int promptCacheTtlSeconds}) = FastModeAvailable;

  /// The model has fast mode, but the account cannot use it right now.
  const factory unavailable({
    @JsonKey(unknownEnumValue: FastModeUnavailableReason.unknown) required FastModeUnavailableReason reason,
  }) = FastModeUnavailable;

  /// A variant this build does not know.
  const factory unknown() = FastModeSupportUnknown;

  factory fromJson(Map<String, dynamic> json) => _$FastModeSupportFromJson(json);
}

/// Why an account cannot use a model's fast mode.
enum FastModeUnavailableReason() {
  extraUsageDisabled,
  outOfCredits,
  disabledByOrganization,
  spendLimitReached,
  unknown,
}

/// Response from `GET /provider`.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderListResponse with _$ProviderListResponse {
  const factory({
    required List<ProviderInfo> items,
    required bool connectedOnly,
  }) = _ProviderListResponse;

  factory fromJson(Map<String, dynamic> json) => _$ProviderListResponseFromJson(json);
}
