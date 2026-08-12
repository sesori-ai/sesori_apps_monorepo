import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/codex_tool_outcome_dto.dart";

final class const CodexToolOutcomeDecodeException({
  required final Object cause,
  required final StackTrace stackTrace,
}) implements Exception {
  @override
  String toString() => "CodexToolOutcomeDecodeException: $cause";
}

/// Layer-1 persistence for structured tool outcomes omitted by Codex rollout.
class CodexToolOutcomeStorage({
  required final HostJsonStore _store,
  required final ServerClock _clock,
}) {
  static const String fileName = "codex-tool-outcomes-v1.json";
  static const int _schemaVersion = 1;

  Future<List<CodexStoredToolErrorDto>> readErrors() async {
    final contents = await _store.read(name: fileName);
    final parsed = _parse(contents: contents);
    if (parsed.error == null) return parsed.errors;
    await _quarantineIfStillInvalid(error: parsed.error!);
    return const [];
  }

  Future<void> updateErrors({
    required List<CodexStoredToolErrorDto> Function(
      List<CodexStoredToolErrorDto> current,
    )
    transform,
  }) async {
    await _store.update(
      name: fileName,
      transform: (contents) async {
        final parsed = _parse(contents: contents);
        if (parsed.error != null) {
          Log.w(
            "[codex] replacing an unreadable tool-outcome file",
            parsed.error,
            parsed.error!.stackTrace,
          );
          await _quarantineCurrent();
        }
        final errors = transform(parsed.errors).toList(growable: false);
        if (errors.isEmpty) return null;
        return jsonEncode(
          CodexToolOutcomeFileDto(
            schemaVersion: _schemaVersion,
            errors: errors,
          ).toJson(),
        );
      },
    );
  }

  ({List<CodexStoredToolErrorDto> errors, CodexToolOutcomeDecodeException? error}) _parse({
    required String? contents,
  }) {
    if (contents == null) {
      return (errors: const [], error: null);
    }
    try {
      final file = CodexToolOutcomeFileDto.fromJson(jsonDecodeMap(contents));
      if (file.schemaVersion != _schemaVersion) {
        throw FormatException(
          "unsupported Codex tool-outcome schema ${file.schemaVersion}",
        );
      }
      return (
        errors: List<CodexStoredToolErrorDto>.unmodifiable(file.errors),
        error: null,
      );
    } on Object catch (error, stackTrace) {
      return (
        errors: const [],
        error: CodexToolOutcomeDecodeException(
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _quarantineIfStillInvalid({required Object error}) async {
    try {
      await _store.update(
        name: fileName,
        transform: (contents) async {
          final recheck = _parse(contents: contents);
          if (recheck.error == null) return contents;
          Log.w(
            "[codex] quarantining an unreadable tool-outcome file",
            recheck.error,
            recheck.error!.stackTrace,
          );
          await _quarantineCurrent();
          return null;
        },
      );
    } on Object catch (quarantineError, stackTrace) {
      Log.w(
        "[codex] failed to quarantine the tool-outcome file",
        quarantineError,
        stackTrace,
      );
      Log.w("[codex] original tool-outcome decode failure", error);
    }
  }

  Future<void> _quarantineCurrent() async {
    final suffix = _clock.now().toUtc().microsecondsSinceEpoch;
    final baseName = "$fileName.corrupt-$suffix";
    var quarantinedName = baseName;
    var collision = 0;
    while (await _store.read(name: quarantinedName) != null) {
      collision += 1;
      quarantinedName = "$baseName-$collision";
    }
    await _store.quarantine(
      name: fileName,
      quarantinedName: quarantinedName,
    );
  }
}
