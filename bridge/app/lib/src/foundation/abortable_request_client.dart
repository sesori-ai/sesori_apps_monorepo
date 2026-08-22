import "dart:async";

import "package:http/http.dart" as http;

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

final class const AbortableRequestClient() {
  Future<http.Response> send({
    required http.Client client,
    required String method,
    required Uri url,
    required Map<String, String>? headers,
    required String? body,
    required Duration deadline,
    required AbortSignal? abortSignal,
  }) async {
    if (abortSignal?.isAborted ?? false) throw http.RequestAbortedException(url);

    final abortCompleter = Completer<void>();
    final abortSubscription = abortSignal?.aborts.listen((_) {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    });
    if ((abortSignal?.isAborted ?? false) && !abortCompleter.isCompleted) {
      abortCompleter.complete();
    }
    final deadlineTimer = Timer(deadline, () {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    });
    final request = http.AbortableRequest(method, url, abortTrigger: abortCompleter.future);
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = body;

    try {
      return await http.Response.fromStream(await client.send(request));
    } finally {
      deadlineTimer.cancel();
      await abortSubscription?.cancel();
    }
  }
}
