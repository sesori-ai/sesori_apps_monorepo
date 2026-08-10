import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("downloads a bounded HTTPS raster image once", () async {
    var requests = 0;
    final bytes = base64Decode(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    );
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

  test("does not load stored images before reference delivery is enabled", () async {
    var requests = 0;
    final repository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient((_) async {
          requests++;
          return http.Response("unexpected", 200);
        }),
      ),
    );
    const attachment = MessageAttachment.storedImage(
      attachmentId: "attachment-1",
      bridgeId: "bridge-1",
      mime: "image/png",
      filename: "preview.png",
      byteLength: 1024,
    );

    expect(repository.canLoad(attachment: attachment), isFalse);
    expect(await repository.load(attachment: attachment), isA<MessageImageLoadUnsupported>());
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

  test("uses the declared image MIME extension when the filename is absent", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
    );
    final cases = <({String mime, List<int> bytes, String expectedFilename})>[
      (mime: "image/bmp", bytes: const [0x42, 0x4D], expectedFilename: "image.bmp"),
      (mime: "image/gif", bytes: const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61], expectedFilename: "image.gif"),
      (mime: "image/jpeg", bytes: const [0xFF, 0xD8, 0xFF], expectedFilename: "image.jpg"),
      (
        mime: "image/png",
        bytes: const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        expectedFilename: "image.png",
      ),
      (
        mime: "image/webp",
        bytes: const [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
        expectedFilename: "image.webp",
      ),
    ];

    for (final imageCase in cases) {
      final result = await repository.load(
        attachment: MessageAttachment.inlineImage(
          mime: imageCase.mime,
          base64: base64Encode(imageCase.bytes),
          filename: null,
        ),
      );

      expect(
        (result as MessageImageLoadSuccess).actionFilename,
        imageCase.expectedFilename,
        reason: imageCase.mime,
      );
    }
  });

  test("bounds action filenames by UTF-8 byte length", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
    );
    final bytes = base64Decode(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    );

    final result = await repository.load(
      attachment: MessageAttachment.inlineImage(
        mime: "image/png",
        base64: base64Encode(bytes),
        filename: "${List.filled(200, "😀").join()}.png",
      ),
    );

    final filename = (result as MessageImageLoadSuccess).actionFilename;
    expect(utf8.encode(filename).length, lessThanOrEqualTo(255));
    expect(filename, endsWith(".png"));
  });

  test("replaces Windows device basenames used for action files", () async {
    final repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
    );
    final bytes = base64Decode(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    );

    for (final reservedName in [
      "CON.png",
      "CON.preview.png",
      "aux.jpg",
      "NUL.backup.gif",
      "COM1.webp",
      "lpt9.bmp",
    ]) {
      final result = await repository.load(
        attachment: MessageAttachment.inlineImage(
          mime: "image/png",
          base64: base64Encode(bytes),
          filename: reservedName,
        ),
      );

      expect((result as MessageImageLoadSuccess).actionFilename, "image.png");
    }
  });
}
