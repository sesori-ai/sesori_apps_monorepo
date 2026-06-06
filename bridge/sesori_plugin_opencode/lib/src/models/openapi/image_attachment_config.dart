// GENERATED FILE - DO NOT EDIT BY HAND


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
      "auto_resize": autoResize,
      "max_width": maxWidth,
      "max_height": maxHeight,
      "max_base64_bytes": maxBase64Bytes,
    };
  }

  final bool? autoResize;
  final int? maxWidth;
  final int? maxHeight;
  final int? maxBase64Bytes;
}
