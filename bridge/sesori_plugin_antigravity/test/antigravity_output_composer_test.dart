import "dart:convert";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const composer = AntigravityOutputComposer(
    authorizationMapper: AntigravityAuthorizationMapper(),
    stderrMapper: AntigravityStderrMapper(),
  );
  test("large standard image-bearing JSON is byte-exact through live/replay gates", () async {
    const png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==";
    final params = <String, dynamic>{
      "sessionId": "s",
      "update": {
        "sessionUpdate": "tool_call",
        "toolCallId": "image",
        "status": "completed",
        "content": [
          {
            "type": "content",
            "content": {"type": "image", "mimeType": "image/png", "data": png},
          },
          {
            "type": "content",
            "content": {"type": "text", "text": "synthetic output " * 20000},
          },
        ],
      },
    };
    final bytes = utf8.encode('${jsonEncode({"method": "session/update", "params": params})}\n');
    expect(bytes.length, greaterThan(16384));
    for (var process = 0; process < 2; process++) {
      final gate = composer.compose().stdout!;
      final output = await gate
          .intercept(
            bytes: Stream.fromIterable([
              bytes.sublist(0, 3),
              bytes.sublist(3, 80),
              bytes.sublist(80),
            ]),
          )
          .expand((chunk) => chunk)
          .toList();
      expect(output, bytes);
      final configuration = AcpSessionConfigurationTracker();
      final children = AcpChildSessionTracker();
      final mapper = AntigravityEventMapper(
        launchDirectory: "/synthetic",
        pluginId: "antigravity",
        configurationTracker: configuration,
        childSessions: children,
        protocolMapper: const AntigravityProtocolMapper(),
      );
      final parts = mapper
          .map(AcpNotification(method: AcpMethods.sessionUpdate, params: params))
          .whereType<BridgeSseMessagePartUpdated>();
      expect(
        parts.single.part.state.attachments.single,
        isA<PluginMessageAttachmentInlineImage>().having((a) => a.base64, "image bytes", png),
      );
      await children.dispose();
    }
  });
  test("fresh stdout policies reject split private lines and preserve ordinary failure identity", () async {
    final bytes = utf8.encode(
      '${AntigravityAuthorizationMapper.prefix}https://accounts.google.com/?state=synthetic-secret\n',
    );
    for (var split = 0; split <= bytes.length; split++) {
      await expectLater(
        composer
            .compose()
            .stdout!
            .intercept(
              bytes: Stream.fromIterable([
                bytes.sublist(0, split),
                bytes.sublist(split),
              ]),
            )
            .toList(),
        throwsA(
          isA<AcpOutputInterceptionException>()
              .having((e) => e.cause, "typed failure", isA<PluginAuthenticationRequiredException>())
              .having((e) => e.toString(), "presentation", isNot(contains("synthetic-secret"))),
        ),
      );
    }
    const cause = FormatException("ordinary");
    const wrapper = AcpOutputInterceptionException(cause: cause);
    expect(composer.mapInitializationFailure(error: wrapper), same(wrapper));
  });
}
