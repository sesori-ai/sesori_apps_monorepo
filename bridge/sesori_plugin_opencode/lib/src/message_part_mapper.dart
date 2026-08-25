import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show
        decodedBase64Length,
        isTranscriptImageBase64LengthWithinSizeLimit,
        maxTranscriptImageBytes,
        maxTranscriptImageCandidates,
        maxTranscriptImageCollectionBytes;

import "models/openapi/agent_part.g.dart";
import "models/openapi/compaction_part.g.dart";
import "models/openapi/file_part.g.dart";
import "models/openapi/part.g.dart";
import "models/openapi/patch_part.g.dart";
import "models/openapi/reasoning_part.g.dart";
import "models/openapi/retry_part.g.dart";
import "models/openapi/snapshot_part.g.dart";
import "models/openapi/step_finish_part.g.dart";
import "models/openapi/step_start_part.g.dart";
import "models/openapi/subtask_part.g.dart";
import "models/openapi/text_part.g.dart";
import "models/openapi/tool_part.g.dart";
import "models/openapi/tool_state.g.dart";
import "models/openapi/tool_state_completed.g.dart";
import "models/openapi/tool_state_error.g.dart";
import "models/openapi/tool_state_pending.g.dart";
import "models/openapi/tool_state_running.g.dart";

class const MessagePartMapper() {
  static const String _compactionCommandText = "/compact";
  static const int _maxDataUrlHeaderCharacters = 256;
  static const int _maxRemoteUrlCharacters = 4096;
  static const int _maxMimeCharacters = 255;
  static const Map<String, Set<String>> _supportedInlineRasterExtensions = {
    "image/bmp": {"bmp"},
    "image/gif": {"gif"},
    "image/jpeg": {"jpg", "jpeg"},
    "image/png": {"png"},
    "image/webp": {"webp"},
  };

  /// Maps a generated [Part] union to the plugin-facing [PluginMessagePart].
  ///
  /// Dispatches on the sealed [Part] variants — the generated discriminator
  /// is exposed as distinct Dart types, so there is no string matching on a
  /// `type` field and the common `id`/`sessionID`/`messageID` are read as
  /// strongly-typed, non-null fields (no `?? ""` fallbacks).
  PluginMessagePart mapPart(Part raw) {
    final part = _mapPart(raw);
    if (part case PluginMessagePartFile() || PluginMessagePartTool(state: PluginToolState(attachments: [_, ...]))) {
      return applyAttachmentBudget(parts: [part], maxAttachmentBytes: maxTranscriptImageCollectionBytes).single;
    }
    return part;
  }

  PluginMessagePart _mapPart(Part raw) => switch (raw) {
    TextPart(synthetic: true) => _unknownPart(raw),
    TextPart() => PluginMessagePart.text(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      text: raw.text,
    ),
    ReasoningPart() => PluginMessagePart.reasoning(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      text: raw.text,
    ),
    ToolPart() => PluginMessagePart.tool(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      tool: raw.tool,
      state: _mapToolState(raw.state),
    ),
    SubtaskPart() => PluginMessagePart.subtask(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      prompt: raw.prompt,
      description: raw.description,
      agent: raw.agent,
    ),
    AgentPart() => PluginMessagePart.agent(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      agentName: raw.name,
    ),
    RetryPart() => PluginMessagePart.retry(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      attempt: raw.attempt,
      retryError: raw.error.data.message,
    ),
    FilePart() => _mapFilePart(raw: raw),
    SnapshotPart() => PluginMessagePart.snapshot(id: raw.id, sessionID: raw.sessionID, messageID: raw.messageID),
    PatchPart() => PluginMessagePart.patch(id: raw.id, sessionID: raw.sessionID, messageID: raw.messageID),
    CompactionPart() => PluginMessagePart.text(
      id: raw.id,
      sessionID: raw.sessionID,
      messageID: raw.messageID,
      text: _compactionCommandText,
    ),
    StepStartPart() => PluginMessagePart.stepStart(id: raw.id, sessionID: raw.sessionID, messageID: raw.messageID),
    StepFinishPart() => PluginMessagePart.stepFinish(id: raw.id, sessionID: raw.sessionID, messageID: raw.messageID),
    // `Part` is an `abstract interface` (not `sealed`), so a default arm is
    // required. `PartUnknown` and any future variant fall through here and
    // become an `unknown` part, which downstream mapping filters out.
    _ => _unknownPart(raw),
  };

  List<PluginMessagePart> applyAttachmentBudget({
    required List<PluginMessagePart> parts,
    required int maxAttachmentBytes,
  }) {
    var remainingBytes = maxAttachmentBytes;
    var didLogOverflow = false;

    PluginMessageAttachment bound({required PluginMessageAttachment attachment}) {
      if (attachment case PluginMessageAttachmentInlineImage(:final mime, :final base64, :final filename)) {
        final decodedBytes = decodedBase64Length(base64Data: base64);
        if (decodedBytes <= remainingBytes) {
          remainingBytes -= decodedBytes;
          return attachment;
        }
        if (!didLogOverflow) {
          Log.w("OpenCode message attachments exceed the aggregate retention limit; forwarding metadata only");
          didLogOverflow = true;
        }
        return PluginMessageAttachment.metadata(mime: mime, filename: filename);
      }
      return attachment;
    }

    PluginMessagePart boundPart({required PluginMessagePart part}) => switch (part) {
      PluginMessagePartFile(:final attachment) => part.copyWith(attachment: bound(attachment: attachment)),
      PluginMessagePartTool(:final state) => part.copyWith(
        state: state.copyWith(
          attachments: state.attachments.map((attachment) => bound(attachment: attachment)).toList(growable: false),
        ),
      ),
      _ => part,
    };

    return parts.map((part) => boundPart(part: part)).toList(growable: false);
  }

  PluginMessagePart _mapFilePart({required FilePart raw}) => PluginMessagePart.file(
    id: raw.id,
    sessionID: raw.sessionID,
    messageID: raw.messageID,
    attachment: _mapAttachment(raw: raw, fallbackFilename: null),
  );

  PluginMessageAttachment _mapAttachment({required FilePart raw, required String? fallbackFilename}) {
    final isDataUrl = _isDataUrl(url: raw.url);
    final canParseUri = !isDataUrl && raw.url.length <= _maxRemoteUrlCharacters;
    if (!isDataUrl && !canParseUri) {
      Log.w("OpenCode attachment URL exceeds the transport limit; forwarding metadata only");
    }
    final uri = canParseUri ? Uri.tryParse(raw.url) : null;
    final filename =
        normalizePluginMessageAttachmentFilename(filename: raw.filename) ??
        _filenameFromUri(uri: uri) ??
        fallbackFilename;
    if (isDataUrl) {
      return _mapDataAttachment(raw: raw, filename: filename);
    }

    final mime = _normalizedMime(mime: raw.mime, fallback: null);
    if (uri != null) {
      final scheme = uri.scheme.toLowerCase();
      if ((scheme == "http" || scheme == "https") && uri.host.isNotEmpty && uri.userInfo.isEmpty) {
        return PluginMessageAttachment.remoteUrl(mime: mime, url: uri, filename: filename);
      }
    }
    return PluginMessageAttachment.metadata(mime: mime, filename: filename);
  }

  PluginMessageAttachment _mapDataAttachment({required FilePart raw, required String? filename}) {
    final separator = raw.url.indexOf(",");
    if (separator < 5 || separator - 5 > _maxDataUrlHeaderCharacters) {
      Log.w("OpenCode returned a malformed inline image attachment; forwarding metadata only");
      return PluginMessageAttachment.metadata(
        mime: _normalizedMime(mime: raw.mime, fallback: null),
        filename: filename,
      );
    }

    final header = raw.url.substring(5, separator);
    final headerParts = header.split(";");
    final headerMime = headerParts.isEmpty
        ? null
        : _normalizedValue(value: headerParts.first, maxCharacters: _maxMimeCharacters);
    final mime = _normalizedMime(mime: raw.mime, fallback: headerMime);
    if (!_supportedInlineRasterExtensions.containsKey(mime.split(";").first.trim())) {
      return PluginMessageAttachment.metadata(mime: mime, filename: filename);
    }

    final isBase64 = headerParts.skip(1).any((part) => part.trim().toLowerCase() == "base64");
    if (!isBase64) {
      Log.w("OpenCode returned a malformed inline image attachment; forwarding metadata only");
      return PluginMessageAttachment.metadata(mime: mime, filename: filename);
    }

    final encodedLength = raw.url.length - separator - 1;
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: encodedLength)) {
      Log.w("OpenCode transcript image attachment exceeds the retention limit; forwarding metadata only");
      return PluginMessageAttachment.metadata(mime: mime, filename: filename);
    }

    final normalized = normalizeAttachmentBase64(encoded: raw.url.substring(separator + 1));
    if (normalized == null) {
      Log.w("OpenCode returned an invalid base64 image attachment; forwarding metadata only");
      return PluginMessageAttachment.metadata(mime: mime, filename: filename);
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: normalized.length) ||
        decodedBase64Length(base64Data: normalized) > maxTranscriptImageBytes) {
      Log.w("OpenCode transcript image attachment exceeds the retention limit; forwarding metadata only");
      return PluginMessageAttachment.metadata(mime: mime, filename: filename);
    }
    return PluginMessageAttachment.inlineImage(mime: mime, base64: normalized, filename: filename);
  }

  bool _isDataUrl({required String url}) => url.length >= 5 && url.substring(0, 5).toLowerCase() == "data:";

  String _normalizedMime({required String mime, required String? fallback}) =>
      (_normalizedValue(value: mime, maxCharacters: _maxMimeCharacters) ??
              _normalizedValue(value: fallback, maxCharacters: _maxMimeCharacters) ??
              "application/octet-stream")
          .toLowerCase();

  String? _normalizedValue({required String? value, required int maxCharacters}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return String.fromCharCodes(normalized.runes.take(maxCharacters));
  }

  String? _filenameFromUri({required Uri? uri}) {
    if (uri == null || uri.pathSegments.isEmpty) return null;
    return normalizePluginMessageAttachmentFilename(filename: uri.pathSegments.last);
  }

  /// An unrecognized part shape. Every OpenCode part carries `id`,
  /// `sessionID` and `messageID` on the base schema, so they are read back
  /// from the round-tripped JSON; a part missing them is malformed and
  /// surfaces loudly via the cast rather than being silently defaulted.
  PluginMessagePart _unknownPart(Part raw) {
    final json = raw.toJson();
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return PluginMessagePart.unknown(
      id: map["id"] as String,
      sessionID: map["sessionID"] as String,
      messageID: map["messageID"] as String,
    );
  }

  PluginToolState _mapToolState(ToolState state) {
    final status = switch (state) {
      ToolStatePending() => PluginToolStatus.pending,
      ToolStateRunning() => PluginToolStatus.running,
      ToolStateCompleted() => PluginToolStatus.completed,
      ToolStateError() => PluginToolStatus.error,
      // `ToolState` is an `abstract interface` (not `sealed`); ToolStateUnknown
      // and any future variant map to `unknown`.
      _ => PluginToolStatus.unknown,
    };
    final title = switch (state) {
      ToolStateRunning(:final title) => title,
      ToolStateCompleted(:final title) => title,
      _ => null,
    };
    final output = switch (state) {
      ToolStateCompleted(:final output) => output,
      _ => null,
    };
    final error = switch (state) {
      ToolStateError(:final error) => error,
      _ => null,
    };
    final attachments = switch (state) {
      ToolStateCompleted(:final attachments, :final title) => _mapToolAttachments(
        attachments: attachments,
        title: title,
      ),
      _ => const <PluginMessageAttachment>[],
    };
    return PluginToolState(
      status: status,
      title: title,
      output: output != null && output.length > maxToolOutputLength
          ? String.fromCharCodes(output.runes.take(maxToolOutputLength))
          : output,
      error: error,
      attachments: attachments,
    );
  }

  List<PluginMessageAttachment> _mapToolAttachments({
    required List<FilePart>? attachments,
    required String? title,
  }) {
    final rawAttachments = attachments ?? const <FilePart>[];
    if (rawAttachments.length > maxTranscriptImageCandidates) {
      Log.w("OpenCode tool returned too many attachments; forwarding only the bounded prefix");
    }
    final titleFilename = rawAttachments.length == 1
        ? _filenameFromToolTitle(title: title, mime: rawAttachments.single.mime)
        : null;
    return rawAttachments
        .take(maxTranscriptImageCandidates)
        .map((attachment) => _mapAttachment(raw: attachment, fallbackFilename: titleFilename))
        .toList(growable: false);
  }

  String? _filenameFromToolTitle({required String? title, required String mime}) {
    final filename = normalizePluginMessageAttachmentFilename(filename: title);
    if (filename == null) return null;
    final extensionStart = filename.lastIndexOf(".");
    if (extensionStart <= 0 || extensionStart == filename.length - 1) return null;
    final extension = filename.substring(extensionStart + 1).toLowerCase();
    final normalizedMime = _normalizedMime(mime: mime, fallback: null).split(";").first.trim();
    return (_supportedInlineRasterExtensions[normalizedMime]?.contains(extension) ?? false) ? filename : null;
  }
}
