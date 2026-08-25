import "dart:async";

import "package:sesori_bridge/src/routing/request_handler.dart";
import "package:sesori_bridge/src/routing/request_router.dart";
import "package:sesori_bridge/src/routing/routed_request_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RoutedRequestDispatcher", () {
    test("closes acceptance synchronously and drains every accepted route once", () async {
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final dispatcher = RoutedRequestDispatcher(
        router: RequestRouter(
          handlers: [
            _GatedHandler(path: "/first", started: firstStarted, gate: firstGate),
            _GatedHandler(path: "/second", started: secondStarted, gate: secondGate),
          ],
        ),
      );

      final first = dispatcher.dispatch(
        request: _request(id: "first", path: "/first"),
      );
      final second = dispatcher.dispatch(
        request: _request(id: "second", path: "/second"),
      );

      expect(first, isA<RoutedRequestAccepted>());
      expect(second, isA<RoutedRequestAccepted>());
      expect(firstStarted.isCompleted, isTrue);
      expect(secondStarted.isCompleted, isTrue);

      dispatcher
        ..beginShutdown()
        ..beginShutdown();
      final rejected = dispatcher.dispatch(
        request: _request(id: "rejected", path: "/first"),
      );
      expect(rejected, isA<RoutedRequestShutdownRejected>());
      expect(
        (rejected as RoutedRequestShutdownRejected).response,
        isA<RelayResponse>()
            .having((response) => response.id, "id", "rejected")
            .having((response) => response.status, "status", 503),
      );

      final firstDrain = dispatcher.drain();
      final secondDrain = dispatcher.drain();
      expect(identical(firstDrain, secondDrain), isTrue);
      var drained = false;
      unawaited(firstDrain.whenComplete(() => drained = true));

      secondGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);

      firstGate.complete();
      await firstDrain;
      expect(drained, isTrue);
      expect(
        (await (first as RoutedRequestAccepted).pendingRequest.completion).response.status,
        200,
      );
      expect(
        (await (second as RoutedRequestAccepted).pendingRequest.completion).response.status,
        200,
      );
    });

    test("mapped route failure settles the shared drain", () async {
      final dispatcher = RoutedRequestDispatcher(
        router: RequestRouter(
          handlers: [
            _FailingHandler(),
          ],
        ),
      );

      final dispatch = dispatcher.dispatch(
        request: _request(id: "failure", path: "/failure"),
      );
      expect(dispatch, isA<RoutedRequestAccepted>());

      final drain = dispatcher.drain();
      final response = (await (dispatch as RoutedRequestAccepted).pendingRequest.completion).response;

      expect(response.status, 500);
      expect(response.body, contains("route failed"));
      await drain;
    });
  });
}

class _GatedHandler({
  required String path,
  required final Completer<void> _started,
  required final Completer<void> _gate,
}) extends RequestHandlerBase {
  this : super(HttpMethod.get, path);

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  }) async {
    _started.complete();
    await _gate.future;
    return RelayResponse(
      id: request.id,
      status: 200,
      headers: const {},
      body: "ok",
    );
  }
}

class _FailingHandler() extends RequestHandlerBase {
  this : super(HttpMethod.get, "/failure");

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  }) async {
    throw StateError("route failed");
  }
}

RelayRequest _request({required String id, required String path}) {
  return RelayMessage.request(
    id: id,
    method: "GET",
    path: path,
    headers: const {},
    body: null,
  ) as RelayRequest;
}
