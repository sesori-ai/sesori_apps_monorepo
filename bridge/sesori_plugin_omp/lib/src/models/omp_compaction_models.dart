import "package:freezed_annotation/freezed_annotation.dart";

part "omp_compaction_models.freezed.dart";
part "omp_compaction_models.g.dart";

/// `_omp/compaction/start` params. OMP also sends `reason` and `action`,
/// which no Sesori state depends on.
@Freezed(toJson: false)
sealed class OmpCompactionStartDto with _$OmpCompactionStartDto {
  const factory({required String sessionId}) = _OmpCompactionStartDto;

  factory fromJson(Map<String, dynamic> json) => _$OmpCompactionStartDtoFromJson(json);
}

/// `_omp/compaction/end` params. OMP drops undefined members from the
/// payload, so the optional outcome flags may be missing. `willRetry` is not
/// read: OMP sets it only on a successful compaction, when it will re-send
/// the overflowed turn.
@Freezed(toJson: false)
sealed class OmpCompactionEndDto with _$OmpCompactionEndDto {
  const factory({
    required String sessionId,
    required bool? aborted,

    /// OMP's benign skip: nothing to compact yet, or no model to compact with.
    required bool? skipped,
    required String? errorMessage,
  }) = _OmpCompactionEndDto;

  factory fromJson(Map<String, dynamic> json) => _$OmpCompactionEndDtoFromJson(json);
}
