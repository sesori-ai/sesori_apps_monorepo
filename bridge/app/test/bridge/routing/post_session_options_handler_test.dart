import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/post_session_options_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_options_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("PostSessionOptionsHandler", () {
    late _FakeSessionOptionsService service;
    late PostSessionOptionsHandler handler;

    setUp(() {
      service = _FakeSessionOptionsService();
      handler = PostSessionOptionsHandler(
        service: service,
        pluginIds: const {"plugin"},
      );
    });

    test("handles only POST /session/options", () {
      expect(handler.canHandle(makeRequest("POST", "/session/options")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/options")), isFalse);
      expect(handler.canHandle(makeRequest("POST", "/session/options/extra")), isFalse);
    });

    for (final (description, body) in <(String, String?)>[
      ("missing", null),
      ("malformed", "{"),
      ("invalid", jsonEncode({"projectId": 1, "pluginId": "plugin"})),
      ("empty", jsonEncode({"projectId": " ", "pluginId": "plugin"})),
      ("non-canonical", jsonEncode({"projectId": " project", "pluginId": "plugin"})),
      ("unknown plugin", jsonEncode({"projectId": "project", "pluginId": "unknown"})),
    ]) {
      test("returns typed 400 for $description body", () async {
        final response = await _send(handler: handler, body: body);

        _expectError(response, status: 400, code: SessionOptionsErrorCode.unknown);
        expect(service.calls, isEmpty);
      });
    }

    test("missing refresh loads dynamically", () async {
      final response = await _send(handler: handler, body: _requestBody);

      expect(response.status, 200);
      expect(service.calls, [
        const (
          operation: _SessionOptionsOperation.loadDynamic,
          pluginId: "plugin",
          projectId: "project",
        ),
      ]);
    });

    test("exact false refresh loads cache only", () async {
      final response = await _send(
        handler: handler,
        path: "/session/options?refresh=false",
        body: _requestBody,
      );

      expect(response.status, 200);
      expect(service.calls, [
        const (
          operation: _SessionOptionsOperation.loadCacheOnly,
          pluginId: "plugin",
          projectId: "project",
        ),
      ]);
    });

    test("exact true refreshes explicitly", () async {
      final response = await _send(
        handler: handler,
        path: "/session/options?refresh=true",
        body: _requestBody,
      );

      expect(response.status, 200);
      expect(service.calls, [
        const (
          operation: _SessionOptionsOperation.refreshExplicit,
          pluginId: "plugin",
          projectId: "project",
        ),
      ]);
    });

    for (final refresh in ["", "TRUE", "False", "1"]) {
      test("rejects refresh=$refresh", () async {
        final response = await _send(
          handler: handler,
          path: "/session/options?refresh=${Uri.encodeQueryComponent(refresh)}",
          body: _requestBody,
        );

        _expectError(response, status: 400, code: SessionOptionsErrorCode.unknown);
        expect(service.calls, isEmpty);
      });
    }

    test("maps available options to typed 200 JSON", () async {
      service.outcome = const SessionOptionsAvailable(response: _optionsResponse);

      final response = await _send(handler: handler, body: _requestBody);

      expect(response.status, 200);
      expect(response.headers, containsPair("content-type", "application/json"));
      expect(SessionOptionsResponse.fromJson(jsonDecodeMap(response.body!)), _optionsResponse);
    });

    for (final mapping in <({SessionOptionsOutcome outcome, int status, SessionOptionsErrorCode code})>[
      (
        outcome: const SessionOptionsCacheUnavailable(),
        status: 503,
        code: SessionOptionsErrorCode.cacheUnavailable,
      ),
      (
        outcome: const SessionOptionsProjectNotFound(),
        status: 404,
        code: SessionOptionsErrorCode.projectNotFound,
      ),
      (
        outcome: const SessionOptionsRefreshFailedRetained(
          failure: SessionOptionsKnownRefreshFailure(),
        ),
        status: 502,
        code: SessionOptionsErrorCode.refreshFailedRetained,
      ),
      (
        outcome: const SessionOptionsRefreshFailedUnavailable(
          failure: SessionOptionsKnownRefreshFailure(),
        ),
        status: 502,
        code: SessionOptionsErrorCode.refreshFailedUnavailable,
      ),
    ]) {
      test("maps ${mapping.code.name} to ${mapping.status}", () async {
        service.outcome = mapping.outcome;

        final response = await _send(handler: handler, body: _requestBody);

        _expectError(response, status: mapping.status, code: mapping.code);
      });
    }

    test("maps automatic no-op to safe typed 500", () async {
      service.outcome = const SessionOptionsAutomaticNoOp();

      final response = await _send(handler: handler, body: _requestBody);

      _expectError(response, status: 500, code: SessionOptionsErrorCode.unknown);
    });

    test("does not forward plugin status codes or error text", () async {
      service.error = const PluginOperationException("capture", statusCode: 418, message: "sensitive upstream text");

      final response = await _send(
        handler: handler,
        path: "/session/options?refresh=true",
        body: _requestBody,
      );

      _expectError(response, status: 500, code: SessionOptionsErrorCode.unknown);
      expect(response.body, isNot(contains("sensitive")));
    });
  });
}

const _optionsResponse = SessionOptionsResponse(
  agents: Agents(agents: []),
  providers: ProviderListResponse(items: [], connectedOnly: true),
  commands: CommandListResponse(items: []),
);

final _requestBody = jsonEncode(const PluginProjectIdRequest(projectId: "project", pluginId: "plugin").toJson());

Future<RelayResponse> _send({
  required PostSessionOptionsHandler handler,
  String path = "/session/options",
  required String? body,
}) {
  final request = makeRequest("POST", path, body: body);
  final params = handler.extractParams(request);
  return handler.handleInternal(
    request,
    pathParams: params.pathParams,
    queryParams: params.queryParams,
    fragment: params.fragment,
  );
}

void _expectError(
  RelayResponse response, {
  required int status,
  required SessionOptionsErrorCode code,
}) {
  expect(response.status, status);
  expect(response.headers, containsPair("content-type", "application/json"));
  expect(
    SessionOptionsErrorResponse.fromJson(jsonDecodeMap(response.body!)),
    SessionOptionsErrorResponse(code: code),
  );
}

enum _SessionOptionsOperation { loadDynamic, loadCacheOnly, refreshExplicit }

typedef _SessionOptionsCall = ({
  _SessionOptionsOperation operation,
  String pluginId,
  String projectId,
});

class _FakeSessionOptionsService implements SessionOptionsService {
  SessionOptionsOutcome outcome = const SessionOptionsAvailable(response: _optionsResponse);
  Object? error;
  final List<_SessionOptionsCall> calls = [];

  @override
  Future<SessionOptionsOutcome> loadDynamic({required String pluginId, required String projectId}) {
    calls.add(
      (
        operation: _SessionOptionsOperation.loadDynamic,
        pluginId: pluginId,
        projectId: projectId,
      ),
    );
    return _complete();
  }

  @override
  Future<SessionOptionsOutcome> loadCacheOnly({required String pluginId, required String projectId}) {
    calls.add(
      (
        operation: _SessionOptionsOperation.loadCacheOnly,
        pluginId: pluginId,
        projectId: projectId,
      ),
    );
    return _complete();
  }

  @override
  Future<SessionOptionsOutcome> refreshExplicit({required String pluginId, required String projectId}) {
    calls.add(
      (
        operation: _SessionOptionsOperation.refreshExplicit,
        pluginId: pluginId,
        projectId: projectId,
      ),
    );
    return _complete();
  }

  Future<SessionOptionsOutcome> _complete() async {
    final failure = error;
    if (failure != null) throw failure;
    return outcome;
  }

  @override
  Future<SessionOptionsOutcome> refreshActiveOnly({
    required String pluginId,
    required String projectId,
    required int generation,
  }) async => const SessionOptionsAutomaticNoOp();

  @override
  Future<SessionOptionsOutcome> refreshCurrentActiveOnly({
    required String pluginId,
    required String projectId,
  }) async => const SessionOptionsAutomaticNoOp();

  @override
  Future<SessionOptionsOutcome> refreshActiveOnlyForBackendSession({
    required String pluginId,
    required String backendSessionId,
    required int generation,
  }) async => const SessionOptionsAutomaticNoOp();
}
