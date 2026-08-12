import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/bridge/repositories/attachment_thumbnail_builder.dart";
import "package:test/test.dart";

void main() {
  const builder = AttachmentThumbnailBuilder();

  test("renders opaque images as square JPEG thumbnails", () async {
    final source = image.Image(width: 900, height: 450, numChannels: 3);
    image.fillRect(source, x1: 0, y1: 0, x2: 299, y2: 449, color: image.ColorRgb8(255, 0, 0));
    image.fillRect(source, x1: 300, y1: 0, x2: 599, y2: 449, color: image.ColorRgb8(0, 255, 0));
    image.fillRect(source, x1: 600, y1: 0, x2: 899, y2: 449, color: image.ColorRgb8(0, 0, 255));

    final result = await builder.build(bytes: image.encodePng(source));

    expect(result, isA<AttachmentThumbnailRendered>());
    final rendered = result as AttachmentThumbnailRendered;
    expect(rendered.format, AttachmentThumbnailFormat.jpeg);
    final decoded = image.decodeJpg(rendered.bytes)!;
    expect((decoded.width, decoded.height), (512, 512));
    final center = decoded.getPixel(256, 256);
    expect(center.g, greaterThan(center.r));
    expect(center.g, greaterThan(center.b));
  });

  test("preserves transparency with PNG thumbnails", () async {
    final source = image.Image(width: 8, height: 8, numChannels: 4);
    image.fill(source, color: image.ColorRgba8(30, 80, 140, 0));

    final result = await builder.build(bytes: image.encodePng(source));

    expect(result, isA<AttachmentThumbnailRendered>());
    final rendered = result as AttachmentThumbnailRendered;
    expect(rendered.format, AttachmentThumbnailFormat.png);
    expect(image.decodePng(rendered.bytes)!.getPixel(0, 0).a, 0);
  });

  test("decodes only the first animated frame", () async {
    final animation = image.Image(width: 4, height: 4, numChannels: 3);
    image.fill(animation, color: image.ColorRgb8(255, 0, 0));
    final second = animation.addFrame();
    image.fill(second, color: image.ColorRgb8(0, 0, 255));

    final result = await builder.build(bytes: image.encodeGif(animation));

    final rendered = result as AttachmentThumbnailRendered;
    final decoded = image.decodeJpg(rendered.bytes)!;
    final center = decoded.getPixel(256, 256);
    expect(center.r, greaterThan(center.b));
  });

  test("bakes EXIF orientation before the center crop", () async {
    final source = image.Image(width: 60, height: 20, numChannels: 3);
    image.fillRect(source, x1: 0, y1: 0, x2: 29, y2: 19, color: image.ColorRgb8(255, 0, 0));
    image.fillRect(source, x1: 30, y1: 0, x2: 59, y2: 19, color: image.ColorRgb8(0, 0, 255));
    final orientedJpeg = _withExifOrientation(jpeg: image.encodeJpg(source), orientation: 6);

    final result = await builder.build(bytes: orientedJpeg);

    final decoded = image.decodeJpg((result as AttachmentThumbnailRendered).bytes)!;
    final top = decoded.getPixel(256, 100);
    final bottom = decoded.getPixel(256, 412);
    expect(top.r, greaterThan(top.b));
    expect(bottom.b, greaterThan(bottom.r));
  });

  test("rejects corrupt and oversized encoded dimensions", () async {
    expect(
      await builder.build(bytes: Uint8List.fromList([1, 2, 3])),
      isA<AttachmentThumbnailUnsupported>(),
    );
    expect(
      await builder.build(bytes: _oversizedBmp()),
      isA<AttachmentThumbnailTooLarge>(),
    );
  });
}

Uint8List _oversizedBmp() {
  final bytes = Uint8List(54);
  final data = ByteData.sublistView(bytes);
  bytes[0] = 0x42;
  bytes[1] = 0x4d;
  data.setUint32(2, bytes.length, Endian.little);
  data.setUint32(10, 54, Endian.little);
  data.setUint32(14, 40, Endian.little);
  data.setInt32(18, 6000, Endian.little);
  data.setInt32(22, 6000, Endian.little);
  data.setUint16(26, 1, Endian.little);
  data.setUint16(28, 24, Endian.little);
  return bytes;
}

Uint8List _withExifOrientation({required Uint8List jpeg, required int orientation}) {
  final segment = Uint8List.fromList([
    0xff,
    0xe1,
    0x00,
    0x22,
    0x45,
    0x78,
    0x69,
    0x66,
    0x00,
    0x00,
    0x49,
    0x49,
    0x2a,
    0x00,
    0x08,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x12,
    0x01,
    0x03,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    orientation,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
  return Uint8List.fromList([...jpeg.sublist(0, 2), ...segment, ...jpeg.sublist(2)]);
}
