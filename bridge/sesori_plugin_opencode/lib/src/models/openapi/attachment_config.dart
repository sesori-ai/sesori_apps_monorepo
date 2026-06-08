// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.000493Z

import 'image_attachment_config.dart';

class AttachmentConfig {
  const AttachmentConfig({
    this.image,
  });

  factory AttachmentConfig.fromJson(Map<String, dynamic> json) {
    return AttachmentConfig(
      image: json["image"] == null ? null : ImageAttachmentConfig.fromJson(json["image"] as Map<String, dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "image": ?image?.toJson(),
    };
  }

  final ImageAttachmentConfig? image;
}
