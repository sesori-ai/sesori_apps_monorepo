import "package:sesori_shared/sesori_shared.dart";

/// Whether the harness behind a composer carries image attachments all the way
/// to its backend.
///
/// TEMPORARY 2026-08-03: only OpenCode forwards `PromptPart.fileData` today.
/// Codex and Cursor accept the prompt and drop the image part, so offering the
/// attach action there would lose the image without telling anyone. The
/// durable answer is a capability each plugin declares; until the remaining
/// harnesses carry attachments, this hardcoded gate keeps the composer honest.
/// Delete it together with its call sites once they do.
///
/// [pluginId] is `null` while the session's harness is unknown, which keeps
/// attachments off rather than guessing.
bool harnessSupportsPromptAttachments({required String? pluginId}) => pluginId == Harness.opencode.name;
