import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("authentication events expose only variant-specific safe data", () {
    final events = <PluginAuthenticationEvent>[
      PluginAuthenticationDeviceCodeChallenge(
        verificationUri: Uri.https("auth.example", "/device"),
        userCode: "CODE",
      ),
      PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.https("accounts.example", "/authorize"),
        expectedCallbackUri: Uri.http("127.0.0.1", "/callback"),
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
    expect(
      events[1],
      isA<PluginAuthenticationBrowserChallenge>()
          .having(
            (event) => event.authorizationUri,
            "authorizationUri",
            Uri.https("accounts.example", "/authorize"),
          )
          .having(
            (event) => event.expectedCallbackUri,
            "expectedCallbackUri",
            Uri.http("127.0.0.1", "/callback"),
          ),
    );
    expect(events[2], isA<PluginAuthenticationCompleted>());
    expect(
      events[3],
      isA<PluginAuthenticationFailed>().having(
        (event) => event.message,
        "message",
        "Sanitized failure",
      ),
    );
  });

  test("authentication operations expose a sealed continuation kind", () async {
    Uri? submitted;
    final browser = PluginAuthenticationOperation(
      events: const Stream<PluginAuthenticationEvent>.empty(),
      kind: PluginAuthenticationBrowserOperationKind(
        submitRedirect: ({required redirectUri}) async => submitted = redirectUri,
      ),
    );
    final redirectUri = Uri.http("127.0.0.1", "/callback", {"code": "code"});

    await (browser.kind as PluginAuthenticationBrowserOperationKind).submitRedirect(
      redirectUri: redirectUri,
    );

    expect(submitted, redirectUri);
    expect(
      const PluginAuthenticationOperation(
        events: Stream<PluginAuthenticationEvent>.empty(),
        kind: PluginAuthenticationDeviceCodeOperationKind(),
      ).kind,
      isA<PluginAuthenticationDeviceCodeOperationKind>(),
    );
  });
}
