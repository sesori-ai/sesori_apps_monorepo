// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';
import 'form_fields_1.g.dart';
import 'integration_method.g.dart';

@immutable
class IntegrationOAuthMethod implements IntegrationMethod {
  const IntegrationOAuthMethod({
    required this.id,
    required this.label,
    required this.form,
  });

  factory IntegrationOAuthMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationOAuthMethod(
      id: json["id"] as String,
      label: json["label"] as String,
      form: json["form"] == null ? null : FormFields1.fromJson(json["form"] as List<dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "oauth",
      "label": label,
      "form": ?form?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationOAuthMethod copyWith({
    String? id,
    String? label,
    FormFields1? form,
  }) {
    return IntegrationOAuthMethod(
      id: id ?? this.id,
      label: label ?? this.label,
      form: form ?? this.form,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationOAuthMethod &&
          other.id == id &&
          other.label == label &&
          other.form == form);

  @override
  int get hashCode => Object.hash(id, label, form);

  final String id;
  final String label;
  final FormFields1? form;
}
