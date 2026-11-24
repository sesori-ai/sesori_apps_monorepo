import "package:freezed_annotation/freezed_annotation.dart";

part "gh_graphql_response_dto.freezed.dart";
part "gh_graphql_response_dto.g.dart";

/// The envelope of a `gh api graphql` reply. `data` stays untyped here because
/// each query has its own root; [GhCliApi] reads the root it asked for.
@Freezed(fromJson: true, toJson: false)
sealed class GhGraphQlResponseDto with _$GhGraphQlResponseDto {
  const factory({
    required Map<String, dynamic>? data,
    @Default(<GhGraphQlErrorDto>[]) List<GhGraphQlErrorDto> errors,
  }) = _GhGraphQlResponseDto;

  factory fromJson(Map<String, dynamic> json) => _$GhGraphQlResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhGraphQlErrorDto with _$GhGraphQlErrorDto {
  const factory({required String? message}) = _GhGraphQlErrorDto;

  factory fromJson(Map<String, dynamic> json) => _$GhGraphQlErrorDtoFromJson(json);
}
