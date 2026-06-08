// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.988262Z


class ImageAttachmentConfig {
  const ImageAttachmentConfig({
    this.autoResize,
    this.maxWidth,
    this.maxHeight,
    this.maxBase64Bytes,
  });

  factory ImageAttachmentConfig.fromJson(Map<String, dynamic> json) {
    return ImageAttachmentConfig(
      autoResize: json["auto_resize"] as bool?,
      maxWidth: json["max_width"] as int?,
      maxHeight: json["max_height"] as int?,
      maxBase64Bytes: json["max_base64_bytes"] as int?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "auto_resize": ?autoResize,
      "max_width": ?maxWidth,
      "max_height": ?maxHeight,
      "max_base64_bytes": ?maxBase64Bytes,
    };
  }

  final bool? autoResize;
  final int? maxWidth;
  final int? maxHeight;
  final int? maxBase64Bytes;
}
