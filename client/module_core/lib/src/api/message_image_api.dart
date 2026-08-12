import "dart:async";
import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

sealed class const MessageImageApiResult();

final class const MessageImageApiSuccess({required final Uint8List bytes}) extends MessageImageApiResult;

final class const MessageImageApiHttpFailure({required final int statusCode}) extends MessageImageApiResult;

final class const MessageImageApiTooLarge() extends MessageImageApiResult;

final class const MessageImageApiInvalidRedirect() extends MessageImageApiResult;

final class const MessageImageApiNetworkFailure({
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  required final Object cause,
  required final StackTrace stackTrace,
}) extends MessageImageApiResult;

/// Layer-1 HTTP access for bounded remote message images.
@lazySingleton
class MessageImageApi({required final http.Client _client}) {
  static const _maxRedirects = 5;

  Future<MessageImageApiResult> fetch({
    required Uri url,
    required int maxBytes,
    required Duration timeout,
  }) async {
    final deadline = Completer<void>();
    final timer = Timer(timeout, deadline.complete);
    try {
      var currentUrl = url;
      var redirectCount = 0;
      late http.StreamedResponse response;
      while (true) {
        final request = http.AbortableRequest("GET", currentUrl, abortTrigger: deadline.future)
          ..followRedirects = false;
        response = await _client.send(request);
        if (!_isRedirect(statusCode: response.statusCode)) break;

        final location = response.headers["location"];
        await response.stream.listen(null).cancel();
        if (location == null || redirectCount >= _maxRedirects) {
          return const MessageImageApiInvalidRedirect();
        }
        final redirect = Uri.tryParse(location);
        if (redirect == null) return const MessageImageApiInvalidRedirect();
        final resolved = currentUrl.resolveUri(redirect);
        if (resolved.scheme.toLowerCase() != "https" || resolved.host.isEmpty || resolved.userInfo.isNotEmpty) {
          return const MessageImageApiInvalidRedirect();
        }
        currentUrl = resolved;
        redirectCount++;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.listen(null).cancel();
        return MessageImageApiHttpFailure(statusCode: response.statusCode);
      }
      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > maxBytes) {
        await response.stream.listen(null).cancel();
        return const MessageImageApiTooLarge();
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maxBytes) return const MessageImageApiTooLarge();
        bytes.add(chunk);
      }
      return MessageImageApiSuccess(bytes: bytes.takeBytes());
    } on Object catch (cause, stackTrace) {
      return MessageImageApiNetworkFailure(cause: cause, stackTrace: stackTrace);
    } finally {
      timer.cancel();
    }
  }

  bool _isRedirect({required int statusCode}) =>
      statusCode == 301 || statusCode == 302 || statusCode == 303 || statusCode == 307 || statusCode == 308;
}
