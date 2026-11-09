import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(1), filename: "a.png");
  final file = ComposerFileAttachment(bytes: Uint8List(1), filename: "a.png");

  test("delivers nothing staged whatever the capabilities", () {
    expect(canDeliverComposerAttachments(attachments: const [], inlineImages: null, fileUploads: null), isTrue);
  });

  test("an image needs inline images and a file needs uploads", () {
    expect(canDeliverComposerAttachments(attachments: [image], inlineImages: true, fileUploads: false), isTrue);
    expect(canDeliverComposerAttachments(attachments: [image], inlineImages: false, fileUploads: true), isFalse);
    expect(canDeliverComposerAttachments(attachments: [file], inlineImages: false, fileUploads: true), isTrue);
    expect(canDeliverComposerAttachments(attachments: [file], inlineImages: true, fileUploads: false), isFalse);
  });

  test("every attachment must be deliverable", () {
    expect(canDeliverComposerAttachments(attachments: [image, file], inlineImages: true, fileUploads: true), isTrue);
    expect(canDeliverComposerAttachments(attachments: [image, file], inlineImages: true, fileUploads: false), isFalse);
  });

  test("an unresolved capability delivers neither kind", () {
    expect(canDeliverComposerAttachments(attachments: [image], inlineImages: null, fileUploads: true), isFalse);
    expect(canDeliverComposerAttachments(attachments: [file], inlineImages: true, fileUploads: null), isFalse);
  });

  test("only a known false strands a staged attachment of its kind", () {
    expect(isComposerAttachmentStranded(attachment: image, inlineImages: false, fileUploads: true), isTrue);
    expect(isComposerAttachmentStranded(attachment: file, inlineImages: true, fileUploads: false), isTrue);
    expect(isComposerAttachmentStranded(attachment: image, inlineImages: null, fileUploads: false), isFalse);
    expect(isComposerAttachmentStranded(attachment: file, inlineImages: false, fileUploads: null), isFalse);
  });
}
