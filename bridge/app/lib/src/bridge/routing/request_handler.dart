import "package:sesori_shared/sesori_shared.dart";

/// HTTP methods supported by [RequestHandler].
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,

  /// Matches any HTTP method.
  any
  ;

  /// Returns `true` when this matches the raw method string from a request.
  bool matches(String rawMethod) {
    if (this == any) return true;
    return name.toUpperCase() == rawMethod.toUpperCase();
  }
}

/// A single interceptor in the request routing chain.
///
/// Subclasses declare their [method] and [path] pattern in the constructor.
/// [canHandle] is implemented here and never needs to be overridden — it
/// compares the incoming request against [method] and [path], resolving
/// `:param` placeholders automatically.
///
/// Example:
/// ```dart
/// class GetSessionMessagesHandler extends RequestHandler {
///   GetSessionMessagesHandler(this._plugin)
///       : super(HttpMethod.get, "/session/:id/message");
/// }
/// ```
abstract class RequestHandler {
  /// HTTP method this handler responds to.
  final HttpMethod method;

  /// URL path pattern, optionally containing `:param` placeholders.
  /// Use `"*"` to match any path (catch-all).
  ///
  /// Examples: `"/project"`, `"/session/:id/message"`.
  final String path;

  const RequestHandler(this.method, this.path);

  // ── Matching ────────────────────────────────────────────────────────────────

  /// Returns `true` if this handler is responsible for [request].
  ///
  /// Matches on [method] and the [path] pattern. Subclasses must NOT override
  /// this — declare [method] and [path] in the constructor instead.
  bool canHandle(RelayRequest request) {
    if (!method.matches(request.method)) return false;
    if (path == "*") return true;
    return _matchPathParams(Uri.parse(request.path).path, path) != null;
  }

  /// Extracts path params, query params, and URL fragment from [request].
  ///
  /// Only call this after [canHandle] returned `true` for the same request.
  ({
    Map<String, String> pathParams,
    Map<String, String> queryParams,
    String? fragment,
  })
  extractParams(RelayRequest request) {
    final uri = Uri.parse(request.path);
    final pathParams = path == "*" ? <String, String>{} : (_matchPathParams(uri.path, path) ?? {});
    final queryParams = Map<String, String>.from(uri.queryParameters);
    final fragment = uri.fragment.isEmpty ? null : uri.fragment;
    return (pathParams: pathParams, queryParams: queryParams, fragment: fragment);
  }

  // ── Handler contract ────────────────────────────────────────────────────────

  /// Produces a [RelayResponse] for [request].
  ///
  /// Only called when [canHandle] returned `true` for the same request.
  ///
  /// - [pathParams] — values extracted from `:param` placeholders in [path],
  ///   e.g. `"/session/:id/message"` yields `{"id": "abc"}`.
  /// - [queryParams] — key/value pairs from the query string.
  /// - [fragment] — URL fragment (`#…`), or `null` if absent.
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  });

  // ── Shared helpers ──────────────────────────────────────────────────────────

  /// Case-insensitive header lookup.
  String? findHeader(Map<String, String> headers, String key) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
    }
    return null;
  }

  /// Builds a 200 JSON response.
  RelayResponse buildOkJsonResponse(RelayRequest request, String body) => RelayResponse(
    id: request.id,
    status: 200,
    headers: {"content-type": "application/json"},
    body: body,
  );

  /// Builds an error response with the given [status] and plain-text [message].
  RelayResponse buildErrorResponse(
    RelayRequest request,
    int status,
    String message,
  ) => RelayResponse(
    id: request.id,
    status: status,
    headers: {},
    body: message,
  );

  // ── Path matching internals ─────────────────────────────────────────────────

  /// Matches [requestPath] against [pattern], returning extracted params or
  /// `null` when there is no match.
  ///
  /// Pattern segments starting with `:` are named placeholders that match any
  /// single path segment and capture its value.
  ///
  /// Example: `_matchPathParams("/session/abc/message", "/session/:id/message")`
  /// → `{"id": "abc"}`.
  static Map<String, String>? _matchPathParams(
    String requestPath,
    String pattern,
  ) {
    final patternSegs = pattern.split("/").where((s) => s.isNotEmpty).toList();
    final requestSegs = requestPath.split("/").where((s) => s.isNotEmpty).toList();

    if (patternSegs.length != requestSegs.length) return null;

    final params = <String, String>{};
    for (var i = 0; i < patternSegs.length; i++) {
      final pSeg = patternSegs[i];
      final rSeg = requestSegs[i];
      if (pSeg.startsWith(":")) {
        params[pSeg.substring(1)] = rSeg;
      } else if (pSeg != rSeg) {
        return null;
      }
    }
    return params;
  }
}
