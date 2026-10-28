import "package:freezed_annotation/freezed_annotation.dart";

part "file_preview.freezed.dart";
part "file_preview.g.dart";

/// The largest text file, in bytes, that `POST /filesystem/file` returns.
/// Images use [maxTranscriptImageBytes] instead.
const maxFilePreviewTextBytes = 1024 * 1024;

/// Asks the bridge for a read-only preview of the file at [path], which must
/// be absolute. The client resolves a relative reference before sending it.
@Freezed(fromJson: true, toJson: true)
sealed class FilePreviewRequest with _$FilePreviewRequest {
  const factory({
    required String path,
  }) = _FilePreviewRequest;

  factory fromJson(Map<String, dynamic> json) => _$FilePreviewRequestFromJson(json);
}

/// The bridge's answer to `POST /filesystem/file`. Every variant is a domain
/// outcome sent with HTTP 200, so a 404 means the bridge has no such route.
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class FilePreviewResponse with _$FilePreviewResponse {
  /// A UTF-8 text file of at most [maxFilePreviewTextBytes] bytes.
  @FreezedUnionValue("text")
  const factory text({
    required String content,
  }) = FilePreviewText;

  /// An image of at most [maxTranscriptImageBytes] bytes.
  @FreezedUnionValue("image")
  const factory image({
    required String mime,
    required String base64,
    required int byteLength,
  }) = FilePreviewImage;

  @FreezedUnionValue("missing")
  const factory missing() = FilePreviewMissing;

  @FreezedUnionValue("too_large")
  const factory tooLarge() = FilePreviewTooLarge;

  /// A directory, a binary file, or text that is not UTF-8.
  @FreezedUnionValue("unsupported")
  const factory unsupported() = FilePreviewUnsupported;

  /// The host refused the bridge permission to read the file.
  @FreezedUnionValue("denied")
  const factory denied() = FilePreviewDenied;

  factory fromJson(Map<String, dynamic> json) => _$FilePreviewResponseFromJson(json);
}
