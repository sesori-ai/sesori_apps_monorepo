import "package:freezed_annotation/freezed_annotation.dart";

part "base_branch_response.freezed.dart";
part "base_branch_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BaseBranchResponse with _$BaseBranchResponse {
  const factory BaseBranchResponse({
    required String? baseBranch,
    // Forge-style repository slug (`org/repo`) parsed from the project's git
    // remote by the bridge. Null when the project has no usable remote (not a
    // git repository, no remotes, or a local filesystem remote) — and absent
    // from payloads of bridges that predate the field, which decodes to the
    // same null.
    required String? repoSlug,
    // Hostname the git remote points at (`github.com`), lowercased, without
    // user info or port — lets clients recognise the hosting provider without
    // re-parsing remote URLs. Non-null exactly when [repoSlug] is non-null;
    // absent from payloads of bridges that predate the field, which decodes
    // to null.
    required String? repoHost,
  }) = _BaseBranchResponse;

  factory BaseBranchResponse.fromJson(Map<String, dynamic> json) => _$BaseBranchResponseFromJson(json);
}
