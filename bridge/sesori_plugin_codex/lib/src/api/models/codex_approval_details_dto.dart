import "package:freezed_annotation/freezed_annotation.dart";

part "codex_approval_details_dto.freezed.dart";
part "codex_approval_details_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexApprovalDetailsDto with _$CodexApprovalDetailsDto {
  const factory({
    required String? command,
    required String? itemId,
    required CodexNetworkApprovalContextDto? networkApprovalContext,
  }) = _CodexApprovalDetailsDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexApprovalDetailsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexNetworkApprovalContextDto with _$CodexNetworkApprovalContextDto {
  const factory({required String host}) = _CodexNetworkApprovalContextDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexNetworkApprovalContextDtoFromJson(json);
}
