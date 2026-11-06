import "package:freezed_annotation/freezed_annotation.dart";

part "omp_steering_models.freezed.dart";
part "omp_steering_models.g.dart";

/// The part of OMP's `initialize` result that advertises `_session/steering`:
/// a top-level `_meta.steering.supported`, beside `agentCapabilities`.
@freezed
sealed class OmpInitializeMetaDto with _$OmpInitializeMetaDto {
  const factory({
    @JsonKey(name: "_meta") required OmpInitializeExtensionsDto? meta,
  }) = _OmpInitializeMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$OmpInitializeMetaDtoFromJson(json);
}

@freezed
sealed class OmpInitializeExtensionsDto with _$OmpInitializeExtensionsDto {
  const factory({required OmpSteeringCapabilityDto? steering}) = _OmpInitializeExtensionsDto;

  factory fromJson(Map<String, dynamic> json) => _$OmpInitializeExtensionsDtoFromJson(json);
}

@freezed
sealed class OmpSteeringCapabilityDto with _$OmpSteeringCapabilityDto {
  const factory({required bool? supported}) = _OmpSteeringCapabilityDto;

  factory fromJson(Map<String, dynamic> json) => _$OmpSteeringCapabilityDtoFromJson(json);
}

/// `_session/steering` params. Omitting `_meta.steering.queue` selects OMP's
/// steering queue, which the running turn polls at tool-batch and model-call
/// boundaries (the `followUp` queue would wait for the run to finish).
@Freezed(fromJson: false, toJson: true, copyWith: false, equal: false, toStringOverride: false)
sealed class OmpSteeringParams with _$OmpSteeringParams {
  const factory({
    required String sessionId,

    /// ACP content blocks, the same shape as `session/prompt`'s `prompt`.
    required List<Map<String, dynamic>> prompt,
  }) = _OmpSteeringParams;
}

/// `_session/steering` result outcomes OMP 18.12.6 returns.
enum OmpSteeringOutcome() {
  /// The running turn took the input onto its native steering queue.
  injected,

  /// No client prompt owns a running turn (idle, autonomous wake, or the
  /// abort window); the input was not queued and the host must prompt it.
  promptRequired,

  /// Admission threw; `reason` carries OMP's error message.
  failed,
  unknown,
}

@freezed
sealed class OmpSteeringResultDto with _$OmpSteeringResultDto {
  const factory({
    @JsonKey(unknownEnumValue: OmpSteeringOutcome.unknown) required OmpSteeringOutcome outcome,
    required String? reason,
  }) = _OmpSteeringResultDto;

  factory fromJson(Map<String, dynamic> json) => _$OmpSteeringResultDtoFromJson(json);
}

/// A `_session/steering` request OMP answered without admitting or refusing
/// the input, so the caller cannot know it reached the running turn.
class const OmpSteeringFailedException({
  required final OmpSteeringOutcome outcome,
  required final String? reason,
}) implements Exception {
  @override
  String toString() => "OmpSteeringFailedException(outcome: ${outcome.name}, reason: $reason)";
}
