import "package:json_annotation/json_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";

const httpMethodConverter = HttpMethodConverter();

class HttpMethodConverter implements JsonConverter<HttpMethod, String> {
  const HttpMethodConverter();

  @override
  HttpMethod fromJson(String json) {
    for (final method in HttpMethod.values) {
      if (method.dioName == json) return method;
    }
    throw ArgumentError("Unknown HTTP method: $json");
  }

  @override
  String toJson(HttpMethod object) => object.dioName;
}
