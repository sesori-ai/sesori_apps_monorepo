// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.046369Z


class Pty {
  const Pty({
    required this.id,
    required this.title,
    required this.command,
    required this.args,
    required this.cwd,
    required this.status,
    required this.pid,
  });

  factory Pty.fromJson(Map<String, dynamic> json) {
    return Pty(
      id: json["id"] as String,
      title: json["title"] as String,
      command: json["command"] as String,
      args: (json["args"] as List<dynamic>).cast<String>(),
      cwd: json["cwd"] as String,
      status: json["status"] as String,
      pid: json["pid"] as int,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "title": title,
      "command": command,
      "args": args,
      "cwd": cwd,
      "status": status,
      "pid": pid,
    };
  }

  final String id;
  final String title;
  final String command;
  final List<String> args;
  final String cwd;
  final String status;
  final int pid;
}
