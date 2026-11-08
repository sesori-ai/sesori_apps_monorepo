import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  ComposerAttachment attachment({required ComposerAttachmentKind kind}) =>
      ComposerAttachment(kind: kind, mime: "image/png", bytes: Uint8List(1), filename: "a.png");

  final image = attachment(kind: ComposerAttachmentKind.image);
  final file = attachment(kind: ComposerAttachmentKind.file);

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
}
