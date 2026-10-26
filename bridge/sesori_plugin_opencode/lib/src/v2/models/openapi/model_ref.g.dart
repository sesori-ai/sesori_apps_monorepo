// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';

@immutable
class ModelRef {
  const ModelRef({
    required this.id,
    required this.providerID,
    required this.variant,
  });

  factory ModelRef.fromJson(Map<String, dynamic> json) {
    return ModelRef(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelRef copyWith({
    String? id,
    String? providerID,
    String? variant,
  }) {
    return ModelRef(
      id: id ?? this.id,
      providerID: providerID ?? this.providerID,
      variant: variant ?? this.variant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelRef &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}
