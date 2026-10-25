import "package:json_annotation/json_annotation.dart";

/// What a project row stands for.
///
/// [folder] is an ordinary project folder the user opened or a harness
/// discovered. [scratch] is the bridge's one "No project" project, whose
/// sessions each run in their own bridge-owned folder.
@JsonEnum()
enum ProjectKind() {
  folder,
  scratch,
}
