// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_field.g.dart';

/// Type alias for `List<FormField>` decoded from JSON.
@immutable
class FormFields {
  const FormFields({required this.items});
  factory FormFields.fromJson(List<dynamic> json) => FormFields(items: json.map((e) => FormField.fromJson(e as Map<String, dynamic>)).toList());
  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormFields &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<FormField> items;
}
