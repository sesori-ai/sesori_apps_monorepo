import "package:sesori_bridge/src/foundation/auth_backend_url.dart";
import "package:test/test.dart";

void main() {
  test("normalizes every trailing slash without changing the remaining URL", () {
    expect(normalizeAuthBackendUrl(url: "https://auth.example.test///"), "https://auth.example.test");
    expect(normalizeAuthBackendUrl(url: "https://auth.example.test/base"), "https://auth.example.test/base");
  });
}
