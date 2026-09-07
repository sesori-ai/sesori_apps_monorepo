// ACP raw tool payloads are arbitrary JSON. Known native fields use generated
// DTOs; only this boundary walks untyped payloads.
// ignore_for_file: no_slop_linter/prefer_specific_type

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../models/antigravity_model_catalog.dart";
import "models/antigravity_model_config_dto.dart";
import "models/antigravity_permission_dto.dart";
import "models/antigravity_tool_update_dto.dart";

/// Layer-2 boundary for Antigravity's ACP catalogs, permission requests and tool updates.
class const AntigravityProtocolMapper() {
  static const modelConfigId = "model";
  static const toolTextLimit = 8000;

  /// Runs before either live or replay tool state is retained. Standard content
  /// images remain owned by ACP's existing bounded attachment mapper.
  Map<String, dynamic> normalizeSessionUpdate({required Map<String, dynamic> params}) {
    final raw = params["update"];
    if (raw is! Map<String, dynamic>) return params;
    final update = AntigravityToolUpdateDto.fromJson(raw);
    if (update.sessionUpdate == AntigravityUpdateKind.unknown) return params;
    final input = _nativeFields(raw: update.rawInput);
    final output = _nativeFields(raw: update.rawOutput);
    final command = _label(
      text:
          input?.upperCommandLine ??
          input?.snakeCommandLine ??
          input?.commandLine ??
          input?.command ??
          output?.commandLine ??
          output?.snakeCommandLine,
    );
    final cwd = _label(
      text:
          input?.upperCwd ??
          input?.workingDirectory ??
          input?.snakeWorkingDir ??
          input?.workingDir ??
          input?.cwd ??
          output?.workingDir ??
          output?.snakeWorkingDir,
    );
    final exitCode = output?.exitCode ?? output?.snakeExitCode;
    final nativeOutput = output?.combinedOutput ?? output?.snakeCombinedOutput ?? output?.stdout;
    final display = _displayOutput(nativeOutput: nativeOutput, exitCode: exitCode, content: raw["content"]);
    final normalized = AntigravityNormalizedUpdateDto(
      title: command ?? _label(text: update.title),
      kind: command != null && update.kind == null ? AntigravityNormalizedToolKind.execute : null,
      rawInput: _mergeFields(
        raw: update.rawInput,
        fields: AntigravityNormalizedToolFieldsDto(
          command: command,
          cwd: cwd,
          stdout: null,
          exitCode: null,
          imagePath: null,
        ),
      ),
      rawOutput: _mergeFields(
        raw: update.rawOutput,
        fields: AntigravityNormalizedToolFieldsDto(
          command: null,
          cwd: null,
          stdout: display.text,
          exitCode: exitCode,
          imagePath: _label(text: output?.imagePath),
        ),
      ),
      content: display.content,
      metadata: _AntigravityPayloadBudget().sanitize(value: update.metadata, depth: 0),
    );
    final retained = {...raw}
      ..remove("rawInput")
      ..remove("rawOutput")
      ..remove("_meta");
    return {
      ...params,
      "update": {...retained, ...normalized.toJson()},
    };
  }

  AntigravityNativeToolFieldsDto? _nativeFields({required Object? raw}) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return AntigravityNativeToolFieldsDto.fromJson(raw);
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] malformed native tool fields; retaining bounded raw payload", error, stackTrace);
      return null;
    }
  }

  Object? _mergeFields({required Object? raw, required AntigravityNormalizedToolFieldsDto fields}) {
    final sanitized = _AntigravityPayloadBudget().sanitize(value: raw, depth: 0);
    final canonical = fields.toJson();
    if (canonical.isEmpty) return sanitized;
    return {if (sanitized is Map<String, Object?>) ...sanitized, ...canonical};
  }

  ({String? text, List<Object?>? content}) _displayOutput({
    required String? nativeOutput,
    required int? exitCode,
    required Object? content,
  }) {
    if (nativeOutput == null && (exitCode == null || exitCode == 0)) return (text: null, content: null);
    final retained = <Object?>[];
    final text = StringBuffer();
    // ACP tool content is a list. Decode only text; preserve the original
    // non-text entries so valid image bytes and metadata are not reserialized.
    if (content is List) {
      for (final entry in content) {
        final block = entry is Map<String, dynamic> ? AntigravityToolContentDto.fromJson(entry) : null;
        switch (block) {
          case AntigravityWrappedToolContentDto(content: AntigravityTextToolContentDto(text: final value)) ||
              AntigravityTextToolContentDto(text: final value):
            text.write(value);
          case null || AntigravityToolContentDto():
            retained.add(entry);
        }
      }
    } else if (content is String) {
      text.write(content);
    }
    final note = exitCode != null && exitCode != 0 ? "\n[Process exit code: $exitCode]" : "";
    // Respect the existing shared display cap so its later prefix truncation
    // cannot discard the process exit note. Raw fields retain their own budget.
    final display = "${_bound(text: nativeOutput ?? text.toString(), limit: maxToolOutputLength - note.length)}$note";
    return (
      text: display,
      content: content == null
          ? null
          : [
              AntigravityToolContentDto.content(content: AntigravityToolContentDto.text(text: display)).toJson(),
              ...retained,
            ],
    );
  }

  String? _label({required String? text}) {
    final value = text?.trim();
    return value == null || value.isEmpty ? null : _bound(text: value, limit: toolTextLimit);
  }

  static String _bound({required String text, required int limit}) {
    if (text.length <= limit) return text;
    const marker = "[Earlier output truncated]\n\n";
    return "$marker${text.substring(text.length - limit + marker.length)}";
  }

  AntigravityPermissionRequestDto? mapPermissionRequest({required AcpServerRequest request}) =>
      request.method == AcpMethods.sessionRequestPermission
      ? AntigravityPermissionRequestDto.fromJson(request.params)
      : null;

  AntigravityModelCatalog? mapModelCatalog({required AcpNewSessionResult result}) {
    final selectors = result.configOptions.where((option) => option["id"] == modelConfigId).toList();
    if (selectors.isEmpty) return null;
    if (selectors.length != 1) throw const FormatException("Duplicate Antigravity model selectors");
    final config = AntigravityModelConfigDto.fromJson(selectors.single);
    if (config.type != AntigravityConfigType.select) {
      throw const FormatException("Antigravity model selector is not a supported select option");
    }
    return AntigravityModelCatalog(
      configId: config.id,
      currentModelId: config.currentValue,
      models: [for (final option in config.options) AntigravityModelOption(id: option.value, name: option.name)],
    );
  }
}

/// Per-payload budget for arbitrary native JSON, following the pinned provider
/// boundary (512 nodes, 64k text, depth12). Known native fields use DTOs above;
/// this walker only removes redundant image bytes/duplicate formatted output.
class _AntigravityPayloadBudget() {
  int _nodes = 512;
  int _text = 64000;
  static final _inlineImage = RegExp("^data:image/", caseSensitive: false);

  Object? sanitize({required Object? value, required int depth}) {
    if (depth > 12 || _nodes-- <= 0) return null;
    if (value is String) {
      if (_inlineImage.hasMatch(value) || _text <= 0) return null;
      final limit = _text < AntigravityProtocolMapper.toolTextLimit ? _text : AntigravityProtocolMapper.toolTextLimit;
      // The tail marker itself must fit the remaining aggregate text budget.
      final text = limit < 32
          ? value.substring(0, value.length < limit ? value.length : limit)
          : AntigravityProtocolMapper._bound(text: value, limit: limit);
      _text -= text.length;
      return text;
    }
    if (value is List) {
      final result = <Object?>[];
      for (final entry in value) {
        if (_nodes <= 0) break;
        final sanitized = sanitize(value: entry, depth: depth + 1);
        if (sanitized != null || entry == null) result.add(sanitized);
      }
      return result;
    }
    if (value is! Map<String, Object?>) return value;
    final result = <String, Object?>{};
    final imageMime = switch (value["mimeType"]) {
      final String mime => mime.startsWith("image/"),
      _ => false,
    };
    for (final entry in value.entries) {
      if (_nodes <= 0) break;
      // These discriminator/key comparisons are at the arbitrary JSON boundary,
      // not domain permission/status policy. Never inspect or decode image bytes.
      if ((value["type"] == "image" && (entry.key == "data" || entry.key == "blob")) ||
          (entry.key == "blob" && imageMime) ||
          ((entry.key == "formatted_output" || entry.key == "formattedOutput") &&
              (entry.value == value["combinedOutput"] || entry.value == value["combined_output"]))) {
        continue;
      }
      final sanitized = sanitize(value: entry.value, depth: depth + 1);
      if (sanitized != null || entry.value == null) result[entry.key] = sanitized;
    }
    return result;
  }
}
