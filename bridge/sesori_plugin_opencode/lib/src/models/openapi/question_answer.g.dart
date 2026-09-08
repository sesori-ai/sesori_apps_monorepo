// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Type alias for `List<String>` decoded from JSON.
@immutable
class QuestionAnswer {
  const QuestionAnswer({required this.items});
  factory QuestionAnswer.fromJson(List<dynamic> json) => QuestionAnswer(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionAnswer &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<String> items;
}
