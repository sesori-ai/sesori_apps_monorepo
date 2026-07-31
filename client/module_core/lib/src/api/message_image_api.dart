import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

sealed class MessageImageApiResult {
  const MessageImageApiResult();
}

final class MessageImageApiSuccess extends MessageImageApiResult {
  final Uint8List bytes;

  const MessageImageApiSuccess({required this.bytes});
}

final class MessageImageApiHttpFailure extends MessageImageApiResult {
  final int statusCode;

  const MessageImageApiHttpFailure({required this.statusCode});
}

final class MessageImageApiTooLarge extends MessageImageApiResult {
  const MessageImageApiTooLarge();
}

final class MessageImageApiInvalidRedirect extends MessageImageApiResult {
  const MessageImageApiInvalidRedirect();
}

final class MessageImageApiNetworkFailure extends MessageImageApiResult {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const MessageImageApiNetworkFailure({
    required this.cause,
    required this.stackTrace,
  });
}

/// Layer-1 HTTP access for bounded remote message images.
@lazySingleton
class MessageImageApi {
  static const _maxRedirects = 5;

  final http.Client _client;

  MessageImageApi({required http.Client client}) : _client = client;

  Future<MessageImageApiResult> fetch({
    required Uri url,
    required int maxBytes,
  }) async {
    try {
      var currentUrl = url;
      var redirectCount = 0;
      late http.StreamedResponse response;
      while (true) {
        final request = http.Request("GET", currentUrl)..followRedirects = false;
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
    }
  }

  bool _isRedirect({required int statusCode}) =>
      statusCode == 301 || statusCode == 302 || statusCode == 303 || statusCode == 307 || statusCode == 308;
}
