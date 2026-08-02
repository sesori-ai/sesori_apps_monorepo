/// HTTP methods accepted from routed relay and debug requests.
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,

  /// Handler-only wildcard; external method parsing never produces this value.
  any;

  static HttpMethod? parseExternal({required String rawMethod}) => switch (rawMethod.toUpperCase()) {
    "GET" => get,
    "POST" => post,
    "PUT" => put,
    "PATCH" => patch,
    "DELETE" => delete,
    _ => null,
  };

  String get diagnosticLabel => this == any ? "ANY" : name.toUpperCase();

  bool matches({required HttpMethod requestMethod}) => this == any || this == requestMethod;
}
