import "dart:async";
import "dart:convert";
import "dart:isolate";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/message_image_api.dart";
import "../api/session_api.dart";
import "../foundation/models/image/supported_raster_image_format.dart";
import "../foundation/platform/attachment_thumbnail_storage.dart";
import "../logging/logging.dart";

typedef _StoredRequestScope = ({
  String accountId,
  String bridgeId,
  String sessionId,
  String attachmentId,
  SessionAttachmentRendition rendition,
  int accountGeneration,
});

typedef _StoredImageData = ({Uint8List bytes, String mime});

sealed class const _StoredDataResult();

final class const _StoredDataSuccess({required final _StoredImageData data}) extends _StoredDataResult;

final class const _StoredDataTerminal({required final MessageImageLoadResult result}) extends _StoredDataResult;

final _strictBase64 = RegExp(r"^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$");

Uint8List? _tryDecodeBase64Image(String base64Data) {
  try {
    return base64Decode(base64Data);
  } on FormatException {
    return null;
  }
}

Uint8List? _tryDecodeStrictBase64Image(String base64Data) {
  if (base64Data.length.isOdd || base64Data.length % 4 != 0 || !_strictBase64.hasMatch(base64Data)) {
    return null;
  }
  return _tryDecodeBase64Image(base64Data);
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

final class const MessageImageAuthenticationRequiredException() implements Exception {
  @override
  String toString() => "Authenticated account required to load stored message image";
}

enum MessageImageRequestFailureKind() {
  invalidResponse,
  network,
  rejected,
  unauthenticated,
  unknown,
}

final class const MessageImageRequestException({
  // ignore: no_slop_linter/prefer_specific_type, preserves transport exception type
  required final MessageImageRequestFailureKind kind,
  required final int? statusCode,
  required final Object? innerError,
}) implements Exception {
  @override
  String toString() =>
      "Stored message image request failed (${kind.toString()}${statusCode == null ? "" : ", HTTP $statusCode"})";
}

/// Layer-2 policy and mapping for renderable message image attachments.
@lazySingleton
class MessageImageRepository({
  required final MessageImageApi _api,
  required final SessionApi _sessionApi,
  required final AuthSession _authSession,
  required final AttachmentThumbnailStorage attachmentThumbnailStorage,
}) {
  static const _remoteFetchTimeout = Duration(seconds: 15);
  static const _maxFilenameBytes = 255;
  static const _thumbnailCacheMaxBytes = 64 * 1024 * 1024;
  static const _thumbnailCacheVersion = "message-thumbnail-v1";

  final AttachmentThumbnailStorage _thumbnailStorage = attachmentThumbnailStorage;
  final Sha256 _sha256 = Sha256();
  final Map<_StoredRequestScope, Future<_StoredDataResult>> _activeStoredLoads = {};
  final Map<String, int> _accountGenerations = {};
  final Map<String, Set<Future<_StoredDataResult>>> _startedAccountOperations = {};
  final Map<String, Future<void>> _accountCleanups = {};
  final Set<String> _accountsRequiringCleanup = {};
  bool canLoad({required MessageAttachment attachment}) => switch (attachment) {
    MessageAttachmentInlineImage(:final mime) ||
    MessageAttachmentStoredImage(:final mime) => supportedRasterImageFormatForMime(mime: mime) != null,
    MessageAttachmentRemoteUrl(:final mime) =>
      supportedRasterImageFormatForMime(mime: mime) != null &&
          attachment.safeRemoteUri?.scheme.toLowerCase() == "https",
    MessageAttachmentMetadata() || MessageAttachmentUnknown() => false,
  };

  bool canLoadOriginal({required MessageAttachment attachment}) =>
      attachment is MessageAttachmentStoredImage &&
      attachment.byteLength >= 0 &&
      attachment.byteLength <= maxTranscriptImageBytes &&
      supportedRasterImageFormatForMime(mime: attachment.mime) != null;

  Future<MessageImageLoadResult> load({
    required String sessionId,
    required MessageAttachment attachment,
    required SessionAttachmentRendition rendition,
  }) async {
    if (sessionId.trim().isEmpty) return const MessageImageLoadRejected();
    if (!canLoad(attachment: attachment)) return const MessageImageLoadUnsupported();
    return await (switch (attachment) {
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
      final bytes = await Isolate.run(() => _tryDecodeStrictBase64Image(base64Data));
      if (bytes == null ||
          bytes.length > maxInlineMessageAttachmentBytes ||
          supportedRasterImageFormatForMime(mime: mime)?.hasExpectedSignature(bytes: bytes) != true) {
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
        (supportedRasterImageFormatForMime(mime: mime)?.hasExpectedSignature(bytes: bytes) ?? false)
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
    final accountId = _authenticatedAccountId;
    if (accountId == null) return _authenticationRequired();
    if (accountId.trim().isEmpty ||
        attachment.bridgeId.trim().isEmpty ||
        attachment.attachmentId.trim().isEmpty ||
        attachment.byteLength < 0 ||
        (rendition == SessionAttachmentRendition.original && attachment.byteLength > maxTranscriptImageBytes)) {
      return const MessageImageLoadRejected();
    }

    var useThumbnailCache = false;
    if (rendition == SessionAttachmentRendition.thumbnail) {
      useThumbnailCache = await waitForAccountCleanup(accountId: accountId);
      if (_authenticatedAccountId != accountId) return _authenticationRequired();
    }
    final scope = (
      accountId: accountId,
      bridgeId: attachment.bridgeId,
      sessionId: sessionId,
      attachmentId: attachment.attachmentId,
      rendition: rendition,
      accountGeneration: _accountGenerations[accountId] ?? 0,
    );
    final operation = _activeStoredLoads[scope] ?? _startStoredLoad(scope: scope, useThumbnailCache: useThumbnailCache);
    final result = await operation;
    return switch (result) {
      _StoredDataSuccess(:final data)
          when rendition == SessionAttachmentRendition.original &&
              (data.mime != _normalizedMime(mime: attachment.mime) || data.bytes.length != attachment.byteLength) =>
        const MessageImageLoadRejected(),
      _StoredDataSuccess(:final data) => MessageImageLoadSuccess(
        bytes: data.bytes,
        mime: data.mime,
        actionFilename: _actionFilename(filename: attachment.filename, mime: data.mime),
        originalUri: null,
      ),
      _StoredDataTerminal(:final result) => result,
    };
  }

  Future<_StoredDataResult> _startStoredLoad({
    required _StoredRequestScope scope,
    required bool useThumbnailCache,
  }) {
    final generation = scope.accountGeneration;
    late final Future<_StoredDataResult> operation;
    operation =
        _loadStoredDataWithDerivedKey(
          scope: scope,
          generation: generation,
          useThumbnailCache: useThumbnailCache,
        ).whenComplete(() {
          if (identical(_activeStoredLoads[scope], operation)) {
            _activeStoredLoads.remove(scope);
          }
          _startedAccountOperations[scope.accountId]?.remove(operation);
          if (_startedAccountOperations[scope.accountId]?.isEmpty ?? false) {
            _startedAccountOperations.remove(scope.accountId);
          }
        });
    _activeStoredLoads[scope] = operation;
    if (scope.rendition == SessionAttachmentRendition.thumbnail) {
      (_startedAccountOperations[scope.accountId] ??= {}).add(operation);
    }
    return operation;
  }

  Future<_StoredDataResult> _loadStoredDataWithDerivedKey({
    required _StoredRequestScope scope,
    required int generation,
    required bool useThumbnailCache,
  }) async => await _loadStoredData(
    scope: scope,
    generation: generation,
    cacheScope: useThumbnailCache ? await _accountCacheScope(accountId: scope.accountId) : null,
    cacheKey: useThumbnailCache
        ? await _thumbnailCacheKey(
            bridgeId: scope.bridgeId,
            sessionId: scope.sessionId,
            attachmentId: scope.attachmentId,
          )
        : null,
  );

  Future<_StoredDataResult> _loadStoredData({
    required _StoredRequestScope scope,
    required int generation,
    required String? cacheScope,
    required String? cacheKey,
  }) async {
    if (cacheScope != null && cacheKey != null) {
      final cached = await _readCachedThumbnail(scope: cacheScope, key: cacheKey);
      if (cached != null) return _StoredDataSuccess(data: cached);
    }

    try {
      final response = await _sessionApi.getAttachment(
        sessionId: scope.sessionId,
        attachmentId: scope.attachmentId,
        rendition: scope.rendition,
      );
      final result = switch (response) {
        SuccessResponse(:final data) => await _validateStoredResponse(
          response: data,
          expectedOriginalMime: null,
          expectedOriginalByteLength: null,
          rendition: scope.rendition,
        ),
        ErrorResponse(:final error) => _StoredDataTerminal(result: _storedRequestFailure(error: error)),
      };
      if (result case _StoredDataSuccess(:final data)
          when cacheScope != null && cacheKey != null && generation == (_accountGenerations[scope.accountId] ?? 0)) {
        await _writeAndPruneThumbnail(scope: cacheScope, key: cacheKey, bytes: data.bytes);
      }
      return result;
    } on Object catch (cause, stackTrace) {
      return _StoredDataTerminal(
        result: MessageImageLoadFailure(
          cause: MessageImageRequestException(
            kind: MessageImageRequestFailureKind.unknown,
            statusCode: null,
            innerError: cause,
          ),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<_StoredDataResult> _validateStoredResponse({
    required SessionAttachmentResponse response,
    required String? expectedOriginalMime,
    required int? expectedOriginalByteLength,
    required SessionAttachmentRendition rendition,
  }) async {
    final mime = _normalizedMime(mime: response.mime);
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
    if ((expectedOriginalMime != null && mime != expectedOriginalMime) ||
        supportedRasterImageFormatForMime(mime: mime) == null ||
        response.byteLength < 0 ||
        response.byteLength > maxBytes ||
        !base64WithinLimit) {
      return const _StoredDataTerminal(result: MessageImageLoadRejected());
    }

    final bytes = await Isolate.run(() => _tryDecodeStrictBase64Image(response.base64));
    if (bytes == null ||
        bytes.length != response.byteLength ||
        bytes.length > maxBytes ||
        (expectedOriginalByteLength != null && bytes.length != expectedOriginalByteLength) ||
        supportedRasterImageFormatForMime(mime: mime)?.hasExpectedSignature(bytes: bytes) != true) {
      return const _StoredDataTerminal(result: MessageImageLoadRejected());
    }
    return _StoredDataSuccess(data: (bytes: bytes, mime: mime));
  }

  Future<_StoredImageData?> _readCachedThumbnail({
    required String scope,
    required String key,
  }) async {
    Uint8List? bytes;
    try {
      bytes = await _thumbnailStorage.read(scope: scope, key: key);
    } on Object catch (cause, stackTrace) {
      logw("Failed to read stored message thumbnail cache", cause, stackTrace);
      return null;
    }
    if (bytes == null) return null;
    final mime = _detectedRasterMime(bytes: bytes);
    if (bytes.isEmpty || bytes.length > maxInlineMessageAttachmentBytes || mime == null) {
      try {
        await _thumbnailStorage.delete(scope: scope, key: key);
      } on Object catch (cause, stackTrace) {
        logw("Failed to delete corrupt stored message thumbnail cache entry", cause, stackTrace);
      }
      return null;
    }
    return (bytes: bytes, mime: mime);
  }

  Future<void> _writeAndPruneThumbnail({
    required String scope,
    required String key,
    required Uint8List bytes,
  }) async {
    try {
      await _thumbnailStorage.write(scope: scope, key: key, bytes: bytes);
    } on Object catch (cause, stackTrace) {
      logw("Failed to write stored message thumbnail cache", cause, stackTrace);
      return;
    }

    List<AttachmentThumbnailMetadata> entries;
    try {
      entries = await _thumbnailStorage.listMetadata(scope: scope);
    } on Object catch (cause, stackTrace) {
      logw("Failed to list stored message thumbnail cache", cause, stackTrace);
      return;
    }
    entries.sort((left, right) {
      final modifiedOrder = left.modifiedAt.compareTo(right.modifiedAt);
      return modifiedOrder == 0 ? left.key.compareTo(right.key) : modifiedOrder;
    });
    var totalBytes = entries.fold<int>(0, (total, entry) => total + entry.sizeBytes);
    for (final entry in entries) {
      if (totalBytes <= _thumbnailCacheMaxBytes) break;
      try {
        await _thumbnailStorage.delete(scope: scope, key: entry.key);
        totalBytes -= entry.sizeBytes;
      } on Object catch (cause, stackTrace) {
        logw("Failed to prune stored message thumbnail cache", cause, stackTrace);
      }
    }
  }

  Future<String> _accountCacheScope({required String accountId}) => _hashedSegment(
    value: "$_thumbnailCacheVersion\u0000account\u0000${utf8.encode(accountId).length}\u0000$accountId",
  );

  Future<String> _thumbnailCacheKey({
    required String bridgeId,
    required String sessionId,
    required String attachmentId,
  }) => _hashedSegment(
    value:
        "$_thumbnailCacheVersion\u0000thumbnail\u0000${utf8.encode(bridgeId).length}\u0000$bridgeId"
        "\u0000${utf8.encode(sessionId).length}\u0000$sessionId"
        "\u0000${utf8.encode(attachmentId).length}\u0000$attachmentId",
  );

  Future<String> _hashedSegment({required String value}) async {
    final hash = await _sha256.hash(utf8.encode(value));
    return hash.bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  }

  Future<bool> waitForAccountCleanup({required String accountId}) async {
    while (true) {
      final cleanup = _accountCleanups[accountId];
      if (cleanup == null) break;
      await cleanup;
    }
    if (!_accountsRequiringCleanup.contains(accountId)) return true;
    await _queueAccountCleanup(accountId: accountId, previousCleanup: null);
    return !_accountsRequiringCleanup.contains(accountId);
  }

  Future<void> retireAccountThumbnailCache({required String accountId}) {
    _accountGenerations[accountId] = (_accountGenerations[accountId] ?? 0) + 1;
    _accountsRequiringCleanup.add(accountId);
    return _queueAccountCleanup(
      accountId: accountId,
      previousCleanup: _accountCleanups[accountId],
    );
  }

  Future<void> _queueAccountCleanup({
    required String accountId,
    required Future<void>? previousCleanup,
  }) {
    late final Future<void> cleanup;
    cleanup =
        _retireAccountThumbnailCache(
          accountId: accountId,
          previousCleanup: previousCleanup,
        ).whenComplete(() {
          if (identical(_accountCleanups[accountId], cleanup)) {
            _accountCleanups.remove(accountId);
          }
        });
    _accountCleanups[accountId] = cleanup;
    return cleanup;
  }

  Future<void> _retireAccountThumbnailCache({
    required String accountId,
    required Future<void>? previousCleanup,
  }) async {
    if (previousCleanup != null) await previousCleanup;
    final started = _startedAccountOperations[accountId]?.toList() ?? const <Future<_StoredDataResult>>[];
    await Future.wait(started);
    final scope = await _accountCacheScope(accountId: accountId);
    try {
      await _thumbnailStorage.deleteScope(scope: scope);
      _accountsRequiringCleanup.remove(accountId);
    } on Object catch (cause, stackTrace) {
      logw("Failed to delete retired account thumbnail cache", cause, stackTrace);
    }
  }

  Future<void> waitForThumbnailCacheCleanup() async {
    while (true) {
      final cleanups = _accountCleanups.values.toList();
      if (cleanups.isEmpty) return;
      await Future.wait(cleanups);
    }
  }

  String? get _authenticatedAccountId => switch (_authSession.currentState) {
    AuthAuthenticated(:final user) => user.id,
    AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
  };

  MessageImageLoadFailure _authenticationRequired() => MessageImageLoadFailure(
    cause: const MessageImageAuthenticationRequiredException(),
    stackTrace: StackTrace.current,
  );

  MessageImageLoadFailure _storedRequestFailure({required ApiError error}) {
    final cause = switch (error) {
      DartHttpClientError(:final innerError) => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.network,
        statusCode: null,
        innerError: innerError,
      ),
      JsonParsingError() || EmptyResponseError() => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.invalidResponse,
        statusCode: null,
        innerError: error,
      ),
      NotAuthenticatedError() => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.unauthenticated,
        statusCode: null,
        innerError: error,
      ),
      NonSuccessCodeError(:final errorCode) => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.rejected,
        statusCode: errorCode,
        innerError: error,
      ),
      GenericError() => MessageImageRequestException(
        kind: MessageImageRequestFailureKind.unknown,
        statusCode: null,
        innerError: error,
      ),
    };
    final innerError = cause.innerError;
    final stackTrace = switch (innerError) {
      final Error error => error.stackTrace ?? StackTrace.current,
      _ => error.stackTrace ?? StackTrace.current,
    };
    return MessageImageLoadFailure(cause: cause, stackTrace: stackTrace);
  }

  String? _detectedRasterMime({required Uint8List bytes}) => detectSupportedRasterImageFormat(bytes: bytes)?.mime;

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
    final extension = supportedRasterImageFormatForMime(mime: mime)?.filenameExtension;
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
}
