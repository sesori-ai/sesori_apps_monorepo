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
  const factory text({
    required String text,
  }) = AcpTextContentBlockDto;

  const factory image({
    required String data,
    required String mimeType,
    required String? uri,
  }) = AcpImageContentBlockDto;

  @FreezedUnionValue("audio")
  const factory unsupportedAudio() = AcpUnsupportedAudioContentBlockDto;

  @FreezedUnionValue("resource")
  const factory unsupportedResource() = AcpUnsupportedResourceContentBlockDto;

  @FreezedUnionValue("resource_link")
  const factory unsupportedResourceLink() = AcpUnsupportedResourceLinkContentBlockDto;

  const factory unknown() = AcpUnknownContentBlockDto;

  factory fromJson(Map<String, dynamic> json) => _$AcpContentBlockDtoFromJson(json);
}
