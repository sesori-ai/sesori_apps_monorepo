import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  test("URI diagnostics retain origin but omit user info, path, query and fragment", () {
    final uri = Uri.parse(
      "https://private-user:private-password@example.com:8443/private-path?private-query#private-fragment",
    );
    expect(uri.diagnosticOrigin, "scheme=https, host=example.com, port=8443");
    expect(Uri.parse("mailto:private@example.com").diagnosticOrigin, "scheme=mailto, host=none");
    expect(Uri.parse("file:///private/path").diagnosticOrigin, "scheme=file, host=none");
  });

  test("launch failure keeps its original cause and unrelated diagnostic context", () {
    final uri = Uri.parse("https://example.com/private-path?private-token");
    final cause = StateError("OS code 42: cannot launch $uri; helper /tmp/launcher");
    final failure = ExternalLinkLaunchFailure(url: uri, innerError: cause);
    expect(failure.innerError, same(cause));
    expect(failure.url, same(uri));
    expect(failure.toString(), contains("OS code 42"));
    expect(failure.toString(), contains("helper /tmp/launcher"));
    expect(failure.toString(), contains("scheme=https, host=example.com"));
    expect(failure.toString(), isNot(contains("private-")));
  });

  test("an empty link does not corrupt the diagnostic by replacing empty strings", () {
    final failure = ExternalLinkLaunchFailure(url: Uri(), innerError: StateError("missing scheme"));
    expect(failure.toString(), contains("Bad state: missing scheme"));
  });
}
