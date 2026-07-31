import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("downloads a bounded HTTPS raster image once", () async {
    var requests = 0;
    final bytes = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final repository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient((_) async {
          requests++;
          return http.Response.bytes(bytes, 200);
        }),
      ),
    );

    final result = await repository.load(
      attachment: const MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "https://files.example.com/image.png",
        filename: "../../unsafe.exe",
      ),
    );

    expect(requests, 1);
    expect(result, isA<MessageImageLoadSuccess>());
    final success = result as MessageImageLoadSuccess;
    expect(success.bytes, bytes);
    expect(success.mime, "image/png");
    expect(success.actionFilename, "unsafe.png");
    expect(success.originalUri, Uri.parse("https://files.example.com/image.png"));
  });

  test("rejects a remote response above the attachment limit", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient(
          (_) async => http.Response.bytes(Uint8List(maxInlineMessageAttachmentBytes + 1), 200),
        ),
      ),
    );

    final result = await repository.load(
      attachment: const MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "https://files.example.com/oversized.png",
        filename: "oversized.png",
      ),
    );

    expect(result, isA<MessageImageLoadRejected>());
  });

  test("rejects remote bytes that do not match the declared image MIME", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("not an image", 200))),
    );

    final result = await repository.load(
      attachment: const MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "https://files.example.com/image.png",
        filename: "image.png",
      ),
    );

    expect(result, isA<MessageImageLoadRejected>());
  });

  test("does not fetch an insecure remote raster URL", () async {
    var requests = 0;
    final repository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient((_) async {
          requests++;
          return http.Response("unexpected", 200);
        }),
      ),
    );

    final result = await repository.load(
      attachment: const MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "http://files.example.com/image.png",
        filename: "image.png",
      ),
    );

    expect(result, isA<MessageImageLoadUnsupported>());
    expect(requests, 0);
  });

  test("rejects an HTTPS redirect that downgrades to HTTP", () async {
    var requests = 0;
    final repository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient((_) async {
          requests++;
          return http.Response("", 302, headers: const {"location": "http://files.example.com/image.png"});
        }),
      ),
    );

    final result = await repository.load(
      attachment: const MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "https://files.example.com/image.png",
        filename: "image.png",
      ),
    );

    expect(result, isA<MessageImageLoadRejected>());
    expect(requests, 1);
  });

  test("rejects malformed inline image data", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
    );

    final result = await repository.load(
      attachment: const MessageAttachment.inlineImage(
        mime: "image/png",
        base64: "%%%",
        filename: "broken.png",
      ),
    );

    expect(result, isA<MessageImageLoadRejected>());
  });
}
