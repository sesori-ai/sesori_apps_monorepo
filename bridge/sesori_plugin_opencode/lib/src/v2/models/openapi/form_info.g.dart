// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'form_fields.g.dart';
import 'form_metadata.g.dart';

@immutable
class FormInfo {
  const FormInfo({
    required this.id,
    required this.sessionID,
    required this.title,
    required this.metadata,
    required this.fields,
  });

  factory FormInfo.fromJson(Map<String, dynamic> json) {
    return FormInfo(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      title: json["title"] as String?,
      metadata: json["metadata"] == null ? null : FormMetadata.fromJson(json["metadata"] as Map<String, dynamic>),
      fields: FormFields.fromJson(json["fields"] as List<dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "title": title,
      "metadata": ?metadata?.toJson(),
      "fields": fields.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormInfo copyWith({
    String? id,
    String? sessionID,
    String? title,
    FormMetadata? metadata,
    FormFields? fields,
  }) {
    return FormInfo(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      fields: fields ?? this.fields,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormInfo &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.title == title &&
          other.metadata == metadata &&
          other.fields == fields);

  @override
  int get hashCode => Object.hash(id, sessionID, title, metadata, fields);

  final String id;
  final String sessionID;
  final String? title;
  final FormMetadata? metadata;
  final FormFields fields;
}
