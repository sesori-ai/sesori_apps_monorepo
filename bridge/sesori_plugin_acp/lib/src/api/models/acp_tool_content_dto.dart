import "package:freezed_annotation/freezed_annotation.dart";

import "acp_content_block_dto.dart";

part "acp_tool_content_dto.freezed.dart";
part "acp_tool_content_dto.g.dart";

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class AcpToolContentDto with _$AcpToolContentDto {
  const factory content({
    required AcpContentBlockDto content,
  }) = AcpStandardToolContentDto;

  const factory diff({
    required String path,
    required String? oldText,
    required String newText,
  }) = AcpDiffToolContentDto;

  const factory terminal({
    required String terminalId,
  }) = AcpTerminalToolContentDto;

  const factory unknown() = AcpUnknownToolContentDto;

  factory fromJson(Map<String, dynamic> json) => _$AcpToolContentDtoFromJson(json);
}
