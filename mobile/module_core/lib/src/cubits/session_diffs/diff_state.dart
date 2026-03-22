import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "diff_state.freezed.dart";

@Freezed(fromJson: false, toJson: false)
sealed class DiffState with _$DiffState {
  const factory DiffState.loading() = DiffStateLoading;

  const factory DiffState.loaded({
    required List<FileDiff> files,
    required List<MessageWithParts> messages,
    required bool hasNewChanges,
    String? selectedMessageId,
  }) = DiffStateLoaded;

  const factory DiffState.failed({required Object error}) = DiffStateFailed;
}
