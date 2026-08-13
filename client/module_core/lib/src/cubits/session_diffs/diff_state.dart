import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart" show FileDiff;

part "diff_state.freezed.dart";

@Freezed(fromJson: false, toJson: false)
sealed class DiffState with _$DiffState {
  const factory loading() = DiffStateLoading;

  const factory loaded({
    required List<FileDiff> files,
  }) = DiffStateLoaded;

  const factory failed({required Object error}) = DiffStateFailed;
}
