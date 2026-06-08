// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.910789Z

import 'package:meta/meta.dart';
import 'image_attachment_config.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentConfig &&
          other.image == image);

  @override
  int get hashCode => image.hashCode;

  final ImageAttachmentConfig? image;
}
