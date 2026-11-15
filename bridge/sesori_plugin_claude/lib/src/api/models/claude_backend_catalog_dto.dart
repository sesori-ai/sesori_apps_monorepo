import "package:freezed_annotation/freezed_annotation.dart";

part "claude_backend_catalog_dto.freezed.dart";
part "claude_backend_catalog_dto.g.dart";

/// The catalog-bearing subset of Claude's `initialize` response.
///
/// Agent fields and the account's identity are deliberately absent: account
/// data contains PII, and Claude's first-party agents are outside this
/// plugin's product contract. Only the account's billing route is read.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeBackendCatalogDto with _$ClaudeBackendCatalogDto {
  const factory({
    @JsonKey(fromJson: _commandsOrEmpty) required List<ClaudeCommandDto> commands,
    @JsonKey(fromJson: _modelsOrEmpty) required List<ClaudeModelDto> models,

    /// Why the account cannot use fast mode right now; absent when nothing
    /// blocks it (verified against CLI 2.1.281).
    @JsonKey(name: "fast_mode_disabled_reason", fromJson: _stringOrNull) required String? fastModeDisabledReason,
    @JsonKey(fromJson: _accountOrNull) required ClaudeAccountDto? account,
  }) = _ClaudeBackendCatalogDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeBackendCatalogDtoFromJson(json);
}

/// PII-free subset of the handshake's `account`, which also carries the
/// account's email and organization. Verified against CLI 2.1.325: a
/// subscription login reports `subscriptionType`; an API key reports
/// `apiProvider: firstParty` without it; Bedrock and Vertex report only
/// `apiProvider`. A metered route is therefore recognized by `apiProvider`
/// without `subscriptionType`, so both fields are needed.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeAccountDto with _$ClaudeAccountDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? subscriptionType,
    @JsonKey(fromJson: _stringOrNull) required String? apiProvider,
  }) = _ClaudeAccountDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeAccountDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeCommandDto with _$ClaudeCommandDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? name,
    @JsonKey(fromJson: _stringOrNull) required String? description,
    @JsonKey(fromJson: _stringOrNull) required String? argumentHint,
  }) = _ClaudeCommandDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeCommandDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeModelDto with _$ClaudeModelDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? value,
    @JsonKey(fromJson: _stringOrNull) required String? resolvedModel,
    @JsonKey(fromJson: _stringOrNull) required String? displayName,
    @JsonKey(fromJson: _boolOrNull) required bool? supportsEffort,
    @JsonKey(fromJson: _stringsOrEmpty) required List<String> supportedEffortLevels,

    /// Present and true only on models the CLI can run in fast mode; absent
    /// otherwise (verified against CLI 2.1.281).
    @JsonKey(fromJson: _boolOrNull) required bool? supportsFastMode,
  }) = _ClaudeModelDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeModelDtoFromJson(json);
}

List<ClaudeCommandDto> _commandsOrEmpty(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) ClaudeCommandDto.fromJson(item.cast<String, dynamic>()),
      ]
    : const [];

List<ClaudeModelDto> _modelsOrEmpty(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) ClaudeModelDto.fromJson(item.cast<String, dynamic>()),
      ]
    : const [];

ClaudeAccountDto? _accountOrNull(Object? value) =>
    value is Map ? ClaudeAccountDto.fromJson(value.cast<String, dynamic>()) : null;

List<String> _stringsOrEmpty(Object? value) => value is List ? value.whereType<String>().toList() : const [];

String? _stringOrNull(Object? value) => value is String ? value : null;

bool? _boolOrNull(Object? value) => value is bool ? value : null;
