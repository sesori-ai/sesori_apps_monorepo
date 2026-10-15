// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';
import 'form_fields_2.g.dart';
import 'integration_method.g.dart';

@immutable
class IntegrationKeyMethod implements IntegrationMethod {
  const IntegrationKeyMethod({
    required this.label,
    required this.form,
  });

  factory IntegrationKeyMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationKeyMethod(
      label: json["label"] as String?,
      form: json["form"] == null ? null : FormFields2.fromJson(json["form"] as List<dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "key",
      "label": ?label,
      "form": ?form?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationKeyMethod copyWith({
    String? label,
    FormFields2? form,
  }) {
    return IntegrationKeyMethod(
      label: label ?? this.label,
      form: form ?? this.form,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationKeyMethod &&
          other.label == label &&
          other.form == form);

  @override
  int get hashCode => Object.hash(label, form);

  final String? label;
  final FormFields2? form;
}
