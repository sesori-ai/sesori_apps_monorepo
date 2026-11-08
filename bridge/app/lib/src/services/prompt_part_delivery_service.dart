import "dart:async";
import "dart:convert" show base64Decode;

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/prompt_upload_repository.dart";

/// Decides which prompt parts reach the plugin as they are, and saves every
/// other file on the bridge, so each harness gets a path it can read.
class PromptPartDeliveryService({
  required final PromptUploadRepository _uploads,
  required final Clock _clock,
}) {
  /// Saved files older than this are swept after each save.
  static const uploadLifetime = Duration(days: 30);

  static const _unnamedFileName = "attachment";

  /// Returns [parts] as the plugin should receive them.
  ///
  /// A file part stays as it is only when [inlineImages] is set and its mime
  /// starts with `image/`. Every other file part is saved under [sessionId]
  /// and replaced, in the same position, by a text part naming the saved
  /// path. Other parts pass through. Call it only with parts that will reach
  /// the plugin. A failed save propagates, so the prompt fails visibly.
  Future<List<PromptPart>> deliverableParts({
    required String sessionId,
    required bool inlineImages,
    required List<PromptPart> parts,
  }) async {
    final delivered = <PromptPart>[];
    var savedAny = false;
    for (final part in parts) {
      switch (part) {
        case PromptPartFileData(:final mime) when inlineImages && mime.startsWith("image/"):
          delivered.add(part);
        case PromptPartFileData(:final base64, :final filename):
          final name = filename ?? _unnamedFileName;
          final path = await _uploads.save(sessionId: sessionId, bytes: base64Decode(base64), filename: name);
          delivered.add(
            PromptPart.text(
              text: _note(name: name, path: path),
            ),
          );
          savedAny = true;
        case PromptPartText() || PromptPartFilePath() || PromptPartFileUrl():
          delivered.add(part);
      }
    }
    if (savedAny) unawaited(_sweepExpiredUploads());
    return delivered;
  }

  /// Visible in the user's message. The path is inline code, so it opens the
  /// file preview; a backtick in the original name would end that code early.
  static String _note({required String name, required String path}) {
    return 'Attached file "${name.replaceAll("`", "'")}": `$path`';
  }

  Future<void> _sweepExpiredUploads() async {
    final cutoff = _clock.now().subtract(uploadLifetime);
    try {
      await _uploads.deleteFileFoldersDatedBefore(cutoff: cutoff);
    } on Object catch (error, stackTrace) {
      Log.w("Could not sweep prompt uploads saved before $cutoff", error, stackTrace);
    }
  }
}
