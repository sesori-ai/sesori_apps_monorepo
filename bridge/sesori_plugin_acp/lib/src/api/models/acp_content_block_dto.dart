import "package:freezed_annotation/freezed_annotation.dart";

part "acp_content_block_dto.freezed.dart";
part "acp_content_block_dto.g.dart";

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class AcpContentBlockDto with _$AcpContentBlockDto {
  const factory AcpContentBlockDto.text({
    required String text,
  }) = AcpTextContentBlockDto;

  const factory AcpContentBlockDto.image({
    required String data,
    required String mimeType,
    required String? uri,
  }) = AcpImageContentBlockDto;

  @FreezedUnionValue("audio")
  const factory AcpContentBlockDto.unsupportedAudio() = AcpUnsupportedAudioContentBlockDto;

  @FreezedUnionValue("resource")
  const factory AcpContentBlockDto.unsupportedResource() = AcpUnsupportedResourceContentBlockDto;

  @FreezedUnionValue("resource_link")
  const factory AcpContentBlockDto.unsupportedResourceLink() = AcpUnsupportedResourceLinkContentBlockDto;

  const factory AcpContentBlockDto.unknown() = AcpUnknownContentBlockDto;

  factory AcpContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpContentBlockDtoFromJson(json);
}
