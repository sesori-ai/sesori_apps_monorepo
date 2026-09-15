import "dart:async";
import "dart:typed_data";

import "package:http/http.dart" as http;

class const ResponseBodyTooLargeException({required final Uri uri, required final int statusCode})
    implements Exception {
  @override
  String toString() => "ResponseBodyTooLargeException: $uri returned an oversized response (status $statusCode)";
}

final class AbortSignal() {
  final StreamController<void> _controller = StreamController<void>.broadcast(sync: true);
  bool _aborted = false;

  bool get isAborted => _aborted;
  Stream<void> get aborts => _controller.stream;

  void abort() {
    if (_aborted) return;
    _aborted = true;
    _controller.add(null);
    unawaited(_controller.close());
  }
}

Future<http.Response> sendRequestWithDeadline({
  required http.Client client,
  required String method,
  required Uri url,
  required Map<String, String>? headers,
  required String? body,
  required Duration deadline,
  required int? maxResponseBytes,
}) => sendAbortableRequest(
  client: client,
  method: method,
  url: url,
  headers: headers,
  body: body,
  deadline: deadline,
  abortSignal: null,
  maxResponseBytes: maxResponseBytes,
);

/// Sends one HTTP request whose [deadline] and optional [abortSignal] abort the
/// underlying operation, including response-body consumption.
Future<http.Response> sendAbortableRequest({
  required http.Client client,
  required String method,
  required Uri url,
  required Map<String, String>? headers,
  required String? body,
  required Duration deadline,
  required AbortSignal? abortSignal,
  int? maxResponseBytes,
}) async {
  if (abortSignal?.isAborted ?? false) throw http.RequestAbortedException(url);
  if (maxResponseBytes != null && maxResponseBytes < 0) {
    throw ArgumentError.value(maxResponseBytes, "maxResponseBytes", "must not be negative");
  }

  final abortCompleter = Completer<void>();
  final abortSubscription = abortSignal?.aborts.listen((_) {
    if (!abortCompleter.isCompleted) abortCompleter.complete();
  });
  final deadlineTimer = Timer(deadline, () {
    if (!abortCompleter.isCompleted) abortCompleter.complete();
  });
  final request = http.AbortableRequest(method, url, abortTrigger: abortCompleter.future);
  if (headers != null) request.headers.addAll(headers);
  if (body != null) request.body = body;

  try {
    final response = await client.send(request);
    if (maxResponseBytes != null && response.contentLength != null && response.contentLength! > maxResponseBytes) {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
      throw ResponseBodyTooLargeException(uri: url, statusCode: response.statusCode);
    }

    final bodyBytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (maxResponseBytes != null && bodyBytes.length + chunk.length > maxResponseBytes) {
        if (!abortCompleter.isCompleted) abortCompleter.complete();
        throw ResponseBodyTooLargeException(uri: url, statusCode: response.statusCode);
      }
      bodyBytes.add(chunk);
    }
    return http.Response.bytes(
      bodyBytes.takeBytes(),
      response.statusCode,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  } finally {
    deadlineTimer.cancel();
    await abortSubscription?.cancel();
  }
}
