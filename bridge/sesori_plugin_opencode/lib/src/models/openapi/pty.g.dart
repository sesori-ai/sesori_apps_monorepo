// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class Pty {
  const Pty({
    this.id = '',
    this.title = '',
    this.command = '',
    this.args = const [],
    this.cwd = '',
    this.status = '',
    this.pid = 0,
  });

  factory Pty.fromJson(Map<String, dynamic> json) {
    return Pty(
      id: (json["id"] ?? '') as String,
      title: (json["title"] ?? '') as String,
      command: (json["command"] ?? '') as String,
      args: ((json["args"] ?? const []) as List<dynamic>).cast<String>(),
      cwd: (json["cwd"] ?? '') as String,
      status: (json["status"] ?? '') as String,
      pid: ((json["pid"] ?? 0) as num).toInt(),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Pty copyWith({
    String? id,
    String? title,
    String? command,
    List<String>? args,
    String? cwd,
    String? status,
    int? pid,
  }) {
    return Pty(
      id: id ?? this.id,
      title: title ?? this.title,
      command: command ?? this.command,
      args: args ?? this.args,
      cwd: cwd ?? this.cwd,
      status: status ?? this.status,
      pid: pid ?? this.pid,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pty &&
          other.id == id &&
          other.title == title &&
          other.command == command &&
          const DeepCollectionEquality().equals(other.args, args) &&
          other.cwd == cwd &&
          other.status == status &&
          other.pid == pid);

  @override
  int get hashCode => Object.hash(id, title, command, const DeepCollectionEquality().hash(args), cwd, status, pid);

  final String id;
  final String title;
  final String command;
  final List<String> args;
  final String cwd;
  final String status;
  final int pid;
}
