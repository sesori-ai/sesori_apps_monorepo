import "package:codex_plugin/src/api/models/codex_file_change_dto.dart";
import "package:test/test.dart";

void main() {
  test("fileChange entries keep string fields and degrade malformed ones to empty changes", () {
    final item = CodexFileChangeItemDto.fromJson({
      "type": "fileChange",
      "id": "item-1",
      "status": "completed",
      "changes": [
        {"path": "lib/a.dart", "kind": "update", "diff": "@@ -1 +1 @@"},
        {"path": 7, "diff": false},
        "not an object",
      ],
    });

    expect(item.changes, const [
      CodexFileChangeEntryDto(path: "lib/a.dart", diff: "@@ -1 +1 @@"),
      CodexFileChangeEntryDto(path: null, diff: null),
      CodexFileChangeEntryDto(path: null, diff: null),
    ]);
  });
}
