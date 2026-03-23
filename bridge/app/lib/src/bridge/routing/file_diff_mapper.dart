import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

FileDiff toFileDiff(PluginFileDiff diff) => FileDiff(
  file: diff.file,
  before: diff.before,
  after: diff.after,
  additions: diff.additions,
  deletions: diff.deletions,
  status: mapFileDiffStatus(diff.status),
);

FileDiffStatus? mapFileDiffStatus(String? status) {
  if (status == null) return null;
  return switch (status) {
    "added" => FileDiffStatus.added,
    "deleted" => FileDiffStatus.deleted,
    "modified" => FileDiffStatus.modified,
    _ => null,
  };
}
