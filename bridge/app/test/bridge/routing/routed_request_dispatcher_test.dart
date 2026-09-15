import "dart:async";
import "dart:convert";

import "package:cryptography/cryptography.dart";
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

    test("routes representative signaling between framed boundaries", () async {
      final handler = _SignalingHandler();
      final dispatcher = RoutedRequestDispatcher(
        router: RequestRouter(handlers: [handler]),
      );
      final encryptor = RelayCryptoService().createSessionEncryptor(
        SecretKey(List<int>.generate(32, (index) => index)),
      );
      final offer = _offerFixture();
      final request = RelayRequest(
        id: "signaling",
        method: "POST",
        path: "/test/device-canvas/signaling",
        headers: const {"content-type": "application/json"},
        body: jsonEncode(offer),
      );
      final requestFrame = await frame(utf8.encode(jsonEncode(request.toJson())), encryptor: encryptor);
      final requestPlaintext = await unframe(requestFrame, encryptor: encryptor);
      final decodedRequest = RelayMessage.fromJson(
        jsonDecode(utf8.decode(requestPlaintext)) as Map<String, dynamic>,
      ) as RelayRequest;

      final dispatch = dispatcher.dispatch(request: decodedRequest);

      expect(dispatch, isA<RoutedRequestAccepted>());
      final outcome = await (dispatch as RoutedRequestAccepted).pendingRequest.completion;
      final responseFrame = await frame(
        utf8.encode(jsonEncode(outcome.response.toJson())),
        encryptor: encryptor,
      );
      final responsePlaintext = await unframe(responseFrame, encryptor: encryptor);
      final response = RelayMessage.fromJson(
        jsonDecode(utf8.decode(responsePlaintext)) as Map<String, dynamic>,
      ) as RelayResponse;
      final body = jsonDecode(response.body!) as Map<String, dynamic>;

      expect(response.id, "signaling");
      expect(response.status, 200);
      expect(handler.receivedBody, offer);
      expect(body, _answerFixture());
      expect(_hasMatchingFingerprint(body), isTrue);
    });

    test("rejects a mismatched signaling fingerprint before dispatch", () async {
      final handler = _SignalingHandler();
      final dispatcher = RoutedRequestDispatcher(
        router: RequestRouter(handlers: [handler]),
      );
      final offer = _offerFixture();
      final description = Map<String, dynamic>.from(offer["description"]! as Map<String, dynamic>)
        ..["fingerprint"] = _answerFingerprint;
      offer["description"] = description;

      final dispatch = dispatcher.dispatch(
        request: RelayRequest(
          id: "tampered-signaling",
          method: "POST",
          path: "/test/device-canvas/signaling",
          headers: const {"content-type": "application/json"},
          body: jsonEncode(offer),
        ),
      );

      expect(dispatch, isA<RoutedRequestAccepted>());
      final outcome = await (dispatch as RoutedRequestAccepted).pendingRequest.completion;
      expect(outcome.response.status, 400);
      expect(handler.receivedBody, isNull);
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

class _SignalingHandler() extends BodyRequestHandler<Map<String, dynamic>, Map<String, dynamic>> {
  this
    : super(
        HttpMethod.post,
        "/test/device-canvas/signaling",
        fromJson: (json) {
          if (!_hasMatchingFingerprint(json)) {
            throw const FormatException("description fingerprint does not match SDP");
          }
          return json;
        },
      );

  Map<String, dynamic>? receivedBody;

  @override
  Future<Map<String, dynamic>> handle(
    RelayRequest request, {
    required Map<String, dynamic> body,
  }) async {
    receivedBody = body;
    return _answerFixture();
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

const _offerFingerprint =
    "sha-256 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:10:21:32:43:54:65:76:87:98:A9:BA:CB:DC:ED:FE:0F";
const _answerFingerprint =
    "sha-256 FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00:0F:1E:2D:3C:4B:5A:69:78:87:96:A5:B4:C3:D2:E1:F0";

Map<String, dynamic> _offerFixture() {
  return {
    "bridgeId": "bridge-1",
    "claimRevision": 42,
    "leaseId": "lease-1",
    "description": {
      "type": "offer",
      "sdp": _sdp(
        fingerprint: _offerFingerprint,
        setup: "actpass",
        direction: "recvonly",
        iceUfrag: "offerufrag",
        icePwd: "offerpassword123456789012",
      ),
      "fingerprint": _offerFingerprint,
    },
    "iceCandidates": [
      {
        "candidate": "candidate:1 1 udp 2122260223 192.0.2.1 50000 typ host",
        "sdpMid": "0",
        "sdpMLineIndex": 0,
      },
    ],
  };
}

Map<String, dynamic> _answerFixture() {
  return {
    "bridgeId": "bridge-1",
    "claimRevision": 42,
    "leaseId": "lease-1",
    "description": {
      "type": "answer",
      "sdp": _sdp(
        fingerprint: _answerFingerprint,
        setup: "active",
        direction: "sendonly",
        iceUfrag: "answerufrag",
        icePwd: "answerpassword1234567890",
      ),
      "fingerprint": _answerFingerprint,
    },
    "iceCandidates": [
      {
        "candidate": "candidate:2 1 udp 16777215 192.0.2.2 50001 typ relay raddr 0.0.0.0 rport 0",
        "sdpMid": "0",
        "sdpMLineIndex": 0,
      },
    ],
    "turn": {
      "urls": ["turn:relay.example.com:3478?transport=udp"],
      "username": "ephemeral-user",
      "credential": "ephemeral-secret",
      "expiresAt": "2026-08-25T17:15:00Z",
    },
  };
}

String _sdp({
  required String fingerprint,
  required String setup,
  required String direction,
  required String iceUfrag,
  required String icePwd,
}) {
  return "v=0\r\n"
      "o=- 1 2 IN IP4 127.0.0.1\r\n"
      "s=-\r\n"
      "t=0 0\r\n"
      "m=video 9 UDP/TLS/RTP/SAVPF 96\r\n"
      "c=IN IP4 0.0.0.0\r\n"
      "a=fingerprint:$fingerprint\r\n"
      "a=setup:$setup\r\n"
      "a=ice-ufrag:$iceUfrag\r\n"
      "a=ice-pwd:$icePwd\r\n"
      "a=mid:0\r\n"
      "a=rtcp-mux\r\n"
      "a=$direction\r\n"
      "a=rtpmap:96 H264/90000\r\n";
}

bool _hasMatchingFingerprint(Map<String, dynamic> signaling) {
  final description = signaling["description"] as Map<String, dynamic>?;
  final fingerprint = description?["fingerprint"] as String?;
  final sdp = description?["sdp"] as String?;
  if (fingerprint == null || sdp == null) return false;
  final fingerprintLines = sdp.split("\r\n").where((line) => line.startsWith("a=fingerprint:")).toList();
  return fingerprintLines.length == 1 && fingerprintLines.single == "a=fingerprint:$fingerprint";
}
