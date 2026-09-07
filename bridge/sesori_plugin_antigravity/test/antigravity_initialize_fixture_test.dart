import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("official 1.0.0 initialize fixture preserves the released contract", () {
    final dto = AntigravityInitializeDto.fromJson(
      jsonDecodeMap(File("test/fixtures/official_initialize_1_0_0.json").readAsStringSync()),
    );

    expect(dto.protocolVersion, AntigravityRelease.protocolVersion);
    expect(dto.agentInfo?.name, AntigravityIdentity.upstreamAgentName);
    expect(dto.agentInfo?.title, "Google Antigravity");
    expect(dto.agentInfo?.version, AntigravityRelease.agentVersion);
    expect(dto.agentCapabilities?.loadSession, isTrue);
    expect(dto.agentCapabilities?.sessionCapabilities?.list, isTrue);
    expect(dto.agentCapabilities?.sessionCapabilities?.resume, isTrue);
    expect(dto.agentCapabilities?.sessionCapabilities?.close, isFalse);
    expect(dto.agentCapabilities?.auth?.logout, isTrue);
    expect(
      dto.authMethods?.map((method) => method.id).toSet(),
      AntigravityRelease.advertisedAuthenticationMethodIds,
    );
  });

  test("rejects a malformed capability marker at the generated boundary", () {
    expect(
      () => AntigravityInitializeDto.fromJson({
        "agentCapabilities": {
          "sessionCapabilities": {"list": "invalid"},
        },
      }),
      throwsFormatException,
    );
  });
}
