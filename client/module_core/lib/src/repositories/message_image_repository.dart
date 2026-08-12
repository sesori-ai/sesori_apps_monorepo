import "dart:convert";
import "dart:isolate";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/message_image_api.dart";

Uint8List? _tryDecodeBase64Image(String base64Data) {
  try {
    return base64Decode(base64Data);
  } on FormatException {
    return null;
  }
}

sealed class const MessageImageLoadResult();

final class const MessageImageLoadSuccess({
  required final Uint8List bytes,
  required final String mime,
  required final String actionFilename,
  required final Uri? originalUri,
}) extends MessageImageLoadResult;

final class const MessageImageLoadUnsupported() extends MessageImageLoadResult;

final class const MessageImageLoadRejected() extends MessageImageLoadResult;

final class const MessageImageLoadFailure({
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  required final Object cause,
  required final StackTrace stackTrace,
}) extends MessageImageLoadResult;

/// Layer-2 policy and mapping for renderable message image attachments.
@lazySingleton
class MessageImageRepository({required final MessageImageApi _api}) {
  static const _remoteFetchTimeout = Duration(seconds: 15);
  static const _maxFilenameBytes = 255;
  static const _supportedRasterMimes = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  bool canLoad({required MessageAttachment attachment}) => switch (attachment) {
    MessageAttachmentInlineImage(:final mime) => _supportedRasterMimes.contains(_normalizedMime(mime: mime)),
    MessageAttachmentRemoteUrl(:final mime) =>
      _supportedRasterMimes.contains(_normalizedMime(mime: mime)) &&
          attachment.safeRemoteUri?.scheme.toLowerCase() == "https",
    MessageAttachmentStoredImage() || MessageAttachmentMetadata() || MessageAttachmentUnknown() => false,
  };

  Future<MessageImageLoadResult> load({required MessageAttachment attachment}) async {
    if (!canLoad(attachment: attachment)) return const MessageImageLoadUnsupported();
    return await (switch (attachment) {
      MessageAttachmentInlineImage(:final mime, :final base64, :final filename) => _loadInline(
        mime: _normalizedMime(mime: mime),
        base64Data: base64,
        filename: filename,
      ),
      MessageAttachmentRemoteUrl(:final mime, :final filename) => _loadRemote(
        mime: _normalizedMime(mime: mime),
        uri: attachment.safeRemoteUri,
        filename: filename,
      ),
      MessageAttachmentMetadata() ||
      MessageAttachmentStoredImage() ||
      MessageAttachmentUnknown() => Future<MessageImageLoadResult>.value(const MessageImageLoadUnsupported()),
    });
  }

  Future<MessageImageLoadResult> _loadInline({
    required String mime,
    required String base64Data,
    required String? filename,
  }) async {
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: base64Data.length)) {
      return const MessageImageLoadRejected();
    }
    try {
      final bytes = await Isolate.run(() => _tryDecodeBase64Image(base64Data));
      if (bytes == null ||
          bytes.length > maxInlineMessageAttachmentBytes ||
          !_hasExpectedSignature(bytes: bytes, mime: mime)) {
        return const MessageImageLoadRejected();
      }
      return MessageImageLoadSuccess(
        bytes: bytes,
        mime: mime,
        actionFilename: _actionFilename(filename: filename, mime: mime),
        originalUri: null,
      );
    } on Object catch (cause, stackTrace) {
      return MessageImageLoadFailure(cause: cause, stackTrace: stackTrace);
    }
  }

  Future<MessageImageLoadResult> _loadRemote({
    required String mime,
    required Uri? uri,
    required String? filename,
  }) async {
    if (uri == null) return const MessageImageLoadUnsupported();
    final response = await _api.fetch(
      url: uri,
      maxBytes: maxInlineMessageAttachmentBytes,
      timeout: _remoteFetchTimeout,
    );
    return switch (response) {
      MessageImageApiSuccess(:final bytes) =>
        _hasExpectedSignature(bytes: bytes, mime: mime)
            ? MessageImageLoadSuccess(
                bytes: bytes,
                mime: mime,
                actionFilename: _actionFilename(filename: filename, mime: mime),
                originalUri: uri,
              )
            : const MessageImageLoadRejected(),
      MessageImageApiHttpFailure() ||
      MessageImageApiTooLarge() ||
      MessageImageApiInvalidRedirect() => const MessageImageLoadRejected(),
      MessageImageApiNetworkFailure(:final cause, :final stackTrace) => MessageImageLoadFailure(
        cause: cause,
        stackTrace: stackTrace,
      ),
    };
  }

  static String _normalizedMime({required String mime}) => mime.split(";").first.trim().toLowerCase();

  String _actionFilename({required String? filename, required String mime}) {
    final normalizedFilename = filename?.trim();
    final leaf = normalizedFilename == null || normalizedFilename.isEmpty
        ? null
        : normalizedFilename.split(RegExp(r"[/\\]")).last.trim();
    final extensionStart = leaf?.lastIndexOf(".") ?? -1;
    final basename = leaf == null
        ? null
        : (extensionStart > 0 ? leaf.substring(0, extensionStart) : leaf)
              .replaceAll(RegExp(r'''[<>:"/\\|?*\u0000-\u001F]'''), "_")
              .replaceFirst(RegExp(r"^\.+"), "")
              .replaceFirst(RegExp(r"[. ]+$"), "")
              .trim();
    final extension = switch (mime) {
      "image/bmp" => ".bmp",
      "image/gif" => ".gif",
      "image/jpeg" => ".jpg",
      "image/png" => ".png",
      "image/webp" => ".webp",
      _ => null,
    };
    final maxBasenameBytes = _maxFilenameBytes - (extension == null ? 0 : utf8.encode(extension).length);
    final safeBasename = basename == null || basename.isEmpty || _isReservedWindowsBasename(basename: basename)
        ? "image"
        : _truncateUtf8(value: basename, maxBytes: maxBasenameBytes);
    return extension == null ? safeBasename : "$safeBasename$extension";
  }

  bool _isReservedWindowsBasename({required String basename}) {
    final stem = basename.split(".").first;
    return RegExp(
      r"^(con|prn|aux|nul|com[1-9]|lpt[1-9])$",
      caseSensitive: false,
    ).hasMatch(stem);
  }

  String _truncateUtf8({required String value, required int maxBytes}) {
    final result = StringBuffer();
    var byteCount = 0;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final characterBytes = utf8.encode(character).length;
      if (byteCount + characterBytes > maxBytes) break;
      result.write(character);
      byteCount += characterBytes;
    }
    return result.isEmpty ? "image" : result.toString();
  }

  bool _hasExpectedSignature({required Uint8List bytes, required String mime}) => switch (mime) {
    "image/bmp" => _startsWith(bytes: bytes, signature: const [0x42, 0x4D]),
    "image/gif" =>
      _startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
          _startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
    "image/jpeg" => _startsWith(bytes: bytes, signature: const [0xFF, 0xD8, 0xFF]),
    "image/png" => _startsWith(
      bytes: bytes,
      signature: const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ),
    "image/webp" =>
      _startsWith(bytes: bytes, signature: const [0x52, 0x49, 0x46, 0x46]) &&
          bytes.length >= 12 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50,
    _ => false,
  };

  bool _startsWith({required Uint8List bytes, required List<int> signature}) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }
}
