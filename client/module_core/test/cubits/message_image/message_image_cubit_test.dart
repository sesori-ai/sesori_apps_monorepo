import "dart:async";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("loads attachment bytes through the repository", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
    );
    final cubit = MessageImageCubit(
      repository: repository,
      attachment: const MessageAttachment.inlineImage(
        mime: "image/png",
        base64: "iVBORw0KGgo=",
        filename: "image.png",
      ),
    );
    addTearDown(cubit.close);

    expect(cubit.state, isA<MessageImageLoading>());
    final loaded = await cubit.stream.firstWhere((state) => state is MessageImageLoaded) as MessageImageLoaded;

    expect(loaded.bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(loaded.mime, "image/png");
    expect(loaded.actionFilename, "image.png");
    expect(loaded.originalUri, isNull);
  });

  test("logs remote failures without exposing the attachment URL", () async {
    final previousLogLevel = logLevel;
    setLogLevel(LogLevel.warning);
    addTearDown(() => setLogLevel(previousLogLevel));
    final uri = Uri.parse("https://files.example.com/private/image.png?signature=secret");
    final logs = <String>[];

    late MessageImageFailed failed;
    await runZoned(
      () async {
        final cubit = MessageImageCubit(
          repository: MessageImageRepository(
            api: MessageImageApi(
              client: MockClient((_) async => throw http.ClientException("request failed", uri)),
            ),
          ),
          attachment: MessageAttachment.remoteUrl(
            mime: "image/png",
            url: uri.toString(),
            filename: "image.png",
          ),
        );
        failed = await cubit.stream.firstWhere((state) => state is MessageImageFailed) as MessageImageFailed;
        await cubit.close();
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logs.add(line),
      ),
    );

    expect(failed.cause, isA<http.ClientException>());
    expect(logs, contains("Failed to load a message image"));
    expect(logs.join("\n"), isNot(contains("signature=secret")));
  });
}
