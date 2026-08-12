import "dart:convert";
import "dart:isolate";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/message_image_api.dart";
import "../api/session_api.dart";

typedef _StoredRequestScope = ({
  String accountId,
  String bridgeId,
  String sessionId,
  String attachmentId,
  SessionAttachmentRendition rendition,
});

Uint8List? _tryDecodeBase64Image(String base64Data) {
  try {
    return base64Decode(base64Data);
  } on FormatException {
    return null;
  }
}

sealed class MessageImageLoadResult {
  const MessageImageLoadResult();
}

final class MessageImageLoadSuccess extends MessageImageLoadResult {
  final Uint8List bytes;
  final String mime;
  final String actionFilename;
  final Uri? originalUri;

  const MessageImageLoadSuccess({
    required this.bytes,
    required this.mime,
    required this.actionFilename,
    required this.originalUri,
  });
}

final class MessageImageLoadUnsupported extends MessageImageLoadResult {
  const MessageImageLoadUnsupported();
}

final class MessageImageLoadRejected extends MessageImageLoadResult {
  const MessageImageLoadRejected();
}

final class MessageImageLoadFailure extends MessageImageLoadResult {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const MessageImageLoadFailure({
    required this.cause,
    required this.stackTrace,
  });
}

final class MessageImageAuthenticationRequiredException implements Exception {
  const MessageImageAuthenticationRequiredException();

  @override
  String toString() => "Authenticated account required to load stored message image";
}

enum MessageImageRequestFailureKind { invalidResponse, network, rejected, unauthenticated, unknown }

final class MessageImageRequestException implements Exception {
  final MessageImageRequestFailureKind kind;
  final int? statusCode;
  // ignore: no_slop_linter/prefer_specific_type, preserves transport exception type
  final Object? innerError;

  const MessageImageRequestException({
    required this.kind,
    required this.statusCode,
    required this.innerError,
  });

  @override
  String toString() =>
      "Stored message image request failed (${kind.toString()}${statusCode == null ? "" : ", HTTP $statusCode"})";
}

/// Layer-2 policy and mapping for renderable message image attachments.
@lazySingleton
class MessageImageRepository {
  static const _remoteFetchTimeout = Duration(seconds: 15);
  static const _maxFilenameBytes = 255;
  static final _strictBase64 = RegExp(r"^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$");
  static const _supportedRasterMimes = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  final MessageImageApi _api;
  final SessionApi _sessionApi;
  final AuthSession _authSession;
  final Map<_StoredRequestScope, Future<MessageImageLoadResult>> _activeStoredLoads = {};

  MessageImageRepository({
    required MessageImageApi api,
    required SessionApi sessionApi,
    required AuthSession authSession,
  }) : _api = api,
       _sessionApi = sessionApi,
       _authSession = authSession;

  bool canLoad({required MessageAttachment attachment}) => switch (attachment) {
    MessageAttachmentInlineImage(:final mime) ||
    MessageAttachmentStoredImage(:final mime) => _supportedRasterMimes.contains(_normalizedMime(mime: mime)),
    MessageAttachmentRemoteUrl(:final mime) =>
      _supportedRasterMimes.contains(_normalizedMime(mime: mime)) &&
          attachment.safeRemoteUri?.scheme.toLowerCase() == "https",
    MessageAttachmentMetadata() || MessageAttachmentUnknown() => false,
  };

  bool canLoadOriginal({required MessageAttachment attachment}) =>
      attachment is MessageAttachmentStoredImage &&
      _supportedRasterMimes.contains(_normalizedMime(mime: attachment.mime));

  Future<MessageImageLoadResult> load({
    required String sessionId,
    required MessageAttachment attachment,
    required SessionAttachmentRendition rendition,
  }) async {
    if (sessionId.trim().isEmpty) return const MessageImageLoadRejected();
    if (!canLoad(attachment: attachment)) return const MessageImageLoadUnsupported();
    return switch (attachment) {
      MessageAttachmentInlineImage(:final mime, :final base64, :final filename)
          when rendition == SessionAttachmentRendition.thumbnail =>
        _loadInline(
          mime: _normalizedMime(mime: mime),
          base64Data: base64,
          filename: filename,
        ),
      MessageAttachmentRemoteUrl(:final mime, :final filename) when rendition == SessionAttachmentRendition.thumbnail =>
        _loadRemote(
          mime: _normalizedMime(mime: mime),
          uri: attachment.safeRemoteUri,
          filename: filename,
        ),
      MessageAttachmentStoredImage() => _loadStored(
        sessionId: sessionId,
        attachment: attachment,
        rendition: rendition,
      ),
      MessageAttachmentInlineImage() ||
      MessageAttachmentRemoteUrl() ||
      MessageAttachmentMetadata() ||
      MessageAttachmentUnknown() => Future<MessageImageLoadResult>.value(const MessageImageLoadUnsupported()),
    };
  }

  Future<MessageImageLoadResult> _loadInline({
    required String mime,
    required String base64Data,
    required String? filename,
  }) async {
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: base64Data.length) ||
        !_isStrictBase64(base64Data: base64Data)) {
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

  Future<MessageImageLoadResult> _loadStored({
    required String sessionId,
    required MessageAttachmentStoredImage attachment,
    required SessionAttachmentRendition rendition,
  }) async {
    final accountId = switch (_authSession.currentState) {
      AuthAuthenticated(:final user) => user.id,
      AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
    };
    if (accountId == null) {
      return MessageImageLoadFailure(
        cause: const MessageImageAuthenticationRequiredException(),
        stackTrace: StackTrace.current,
      );
    }
    if (accountId.trim().isEmpty ||
        attachment.bridgeId.trim().isEmpty ||
        attachment.attachmentId.trim().isEmpty ||
        attachment.byteLength < 0) {
      return const MessageImageLoadRejected();
    }

    final scope = (
      accountId: accountId,
      bridgeId: attachment.bridgeId,
      sessionId: sessionId,
      attachmentId: attachment.attachmentId,
      rendition: rendition,
    );
    final active = _activeStoredLoads[scope];
    if (active != null) return active;

    final load = _loadStoredUncoalesced(
      sessionId: sessionId,
      attachment: attachment,
      rendition: rendition,
    );
    _activeStoredLoads[scope] = load;
    try {
      return await load;
    } finally {
      if (identical(_activeStoredLoads[scope], load)) {
        final _ = _activeStoredLoads.remove(scope);
      }
    }
  }

  Future<MessageImageLoadResult> _loadStoredUncoalesced({
    required String sessionId,
    required MessageAttachmentStoredImage attachment,
    required SessionAttachmentRendition rendition,
  }) async {
    try {
      final response = await _sessionApi.getAttachment(
        sessionId: sessionId,
        attachmentId: attachment.attachmentId,
        rendition: rendition,
      );
      return switch (response) {
        SuccessResponse(:final data) => await _validateStoredResponse(
          response: data,
          attachment: attachment,
          rendition: rendition,
        ),
        ErrorResponse(:final error) => _storedRequestFailure(error: error),
      };
    } on Object catch (cause, stackTrace) {
      return MessageImageLoadFailure(
        cause: MessageImageRequestException(
          kind: MessageImageRequestFailureKind.unknown,
          statusCode: null,
          innerError: cause,
        ),
        stackTrace: stackTrace,
      );
    }
  }

  Future<MessageImageLoadResult> _validateStoredResponse({
    required SessionAttachmentResponse response,
    required MessageAttachmentStoredImage attachment,
    required SessionAttachmentRendition rendition,
  }) async {
    final mime = _normalizedMime(mime: response.mime);
    final declaredMime = _normalizedMime(mime: attachment.mime);
    final maxBytes = switch (rendition) {
      SessionAttachmentRendition.thumbnail => maxInlineMessageAttachmentBytes,
      SessionAttachmentRendition.original => maxTranscriptImageBytes,
    };
    final base64WithinLimit = switch (rendition) {
      SessionAttachmentRendition.thumbnail => isInlineMessageAttachmentWithinSizeLimit(
        base64Length: response.base64.length,
      ),
      SessionAttachmentRendition.original => isTranscriptImageBase64LengthWithinSizeLimit(
        base64Length: response.base64.length,
      ),
    };
    if ((rendition == SessionAttachmentRendition.original && mime != declaredMime) ||
        !_supportedRasterMimes.contains(mime) ||
        response.byteLength < 0 ||
        response.byteLength > maxBytes ||
        !base64WithinLimit ||
        !_isStrictBase64(base64Data: response.base64)) {
      return const MessageImageLoadRejected();
    }

    final bytes = await Isolate.run(() => _tryDecodeBase64Image(response.base64));
    if (bytes == null ||
        bytes.length != response.byteLength ||
        bytes.length > maxBytes ||
        (rendition == SessionAttachmentRendition.original && bytes.length != attachment.byteLength) ||
        !_hasExpectedSignature(bytes: bytes, mime: mime)) {
      return const MessageImageLoadRejected();
    }
    return MessageImageLoadSuccess(
      bytes: bytes,
      mime: mime,
      actionFilename: _actionFilename(filename: attachment.filename, mime: mime),
      originalUri: null,
    );
  }

  MessageImageLoadFailure _storedRequestFailure({required ApiError error}) {
    final cause = switch (error) {
      DartHttpClientError(:final innerError) => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.network,
        statusCode: null,
        innerError: innerError,
      ),
      JsonParsingError() || EmptyResponseError() => const MessageImageRequestException(
        kind: MessageImageRequestFailureKind.invalidResponse,
        statusCode: null,
        innerError: null,
      ),
      NotAuthenticatedError() => const MessageImageRequestException(
        kind: MessageImageRequestFailureKind.unauthenticated,
        statusCode: null,
        innerError: null,
      ),
      NonSuccessCodeError(:final errorCode) => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.rejected,
        statusCode: errorCode,
        innerError: null,
      ),
      GenericError() => const MessageImageRequestException(
        kind: MessageImageRequestFailureKind.unknown,
        statusCode: null,
        innerError: null,
      ),
    };
    final innerError = cause.innerError;
    final stackTrace = innerError is Error ? innerError.stackTrace ?? StackTrace.current : StackTrace.current;
    return MessageImageLoadFailure(cause: cause, stackTrace: stackTrace);
  }

  static bool _isStrictBase64({required String base64Data}) =>
      base64Data.length.isEven && base64Data.length % 4 == 0 && _strictBase64.hasMatch(base64Data);

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
