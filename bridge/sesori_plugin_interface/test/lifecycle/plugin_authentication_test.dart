import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("authentication events expose only variant-specific safe data", () {
    final events = <PluginAuthenticationEvent>[
      PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.https("auth.example", "/device"),
        userCode: "CODE",
      ),
      const PluginAuthenticationCompleted(),
      const PluginAuthenticationFailed(message: "Sanitized failure"),
    ];

    expect(
      events[0],
      isA<PluginAuthenticationDeviceCodeChallenge>()
          .having(
            (event) => event.verificationUri,
            "verificationUri",
            Uri.https("auth.example", "/device"),
          )
          .having((event) => event.userCode, "userCode", "CODE"),
    );
    expect(events[1], isA<PluginAuthenticationCompleted>());
    expect(
      events[2],
      isA<PluginAuthenticationFailed>().having(
        (event) => event.message,
        "message",
        "Sanitized failure",
      ),
    );
  });
}
