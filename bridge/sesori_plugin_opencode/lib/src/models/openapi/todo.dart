// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.688469Z


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

  final String content;
  final String status;
  final String priority;
}
