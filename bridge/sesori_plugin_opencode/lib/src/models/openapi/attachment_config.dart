// GENERATED FILE - DO NOT EDIT BY HAND

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
      "image": image?.toJson(),
    };
  }

  final ImageAttachmentConfig? image;
}
