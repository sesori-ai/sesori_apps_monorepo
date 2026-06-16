// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class Todo {
  const Todo({
    required this.content,
    required this.status,
    required this.priority,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      content: json["content"] as String,
      status: json["status"] as String,
      priority: json["priority"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "content": content,
      "status": status,
      "priority": priority,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Todo copyWith({
    String? content,
    String? status,
    String? priority,
  }) {
    return Todo(
      content: content ?? this.content,
      status: status ?? this.status,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.content == content &&
          other.status == status &&
          other.priority == priority);

  @override
  int get hashCode => Object.hash(content, status, priority);

  final String content;
  final String status;
  final String priority;
}
