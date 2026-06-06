// GENERATED FILE - DO NOT EDIT BY HAND


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
