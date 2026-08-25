import "package:opencode_plugin/opencode_plugin.dart";

Project openCodeProject({
  required String id,
  required String worktree,
  String? name,
  List<String> sandboxes = const [],
  ProjectTime time = const ProjectTime(created: 0, updated: 0, initialized: null),
}) => Project(
  time: time,
  sandboxes: sandboxes,
  vcs: null,
  name: name,
  icon: null,
  commands: null,
  id: id,
  worktree: worktree,
);

Session openCodeSession({
  required String id,
  required String directory,
  String projectID = "p1",
  String? parentID,
  String slug = "slug",
  String title = "title",
  SessionTime time = const SessionTime(created: 0, updated: 0, compacting: null, archived: null),
}) => Session(
  slug: slug,
  title: title,
  version: "v",
  time: time,
  id: id,
  projectID: projectID,
  directory: directory,
  workspaceID: null,
  path: null,
  parentID: parentID,
  summary: null,
  cost: null,
  tokens: null,
  share: null,
  agent: null,
  model: null,
  metadata: null,
  permission: null,
  revert: null,
);
