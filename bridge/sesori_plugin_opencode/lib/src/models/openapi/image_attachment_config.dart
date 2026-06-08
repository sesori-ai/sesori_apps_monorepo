// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.971251Z

import 'package:meta/meta.dart';

@immutable
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
      maxWidth: (json["max_width"] as num?)?.toInt(),
      maxHeight: (json["max_height"] as num?)?.toInt(),
      maxBase64Bytes: (json["max_base64_bytes"] as num?)?.toInt(),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageAttachmentConfig &&
          other.autoResize == autoResize &&
          other.maxWidth == maxWidth &&
          other.maxHeight == maxHeight &&
          other.maxBase64Bytes == maxBase64Bytes);

  @override
  int get hashCode => Object.hash(autoResize, maxWidth, maxHeight, maxBase64Bytes);

  final bool? autoResize;
  final int? maxWidth;
  final int? maxHeight;
  final int? maxBase64Bytes;
}
