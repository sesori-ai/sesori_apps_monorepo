// Composes the tray icon variants in assets/tray/ from assets/tray_icon.svg:
// the Sesori mark with a bridge status dot knocked out of its bottom-right
// corner. Run from client/desktop on macOS:
//
//   swift tool/generate_tray_icons.swift
//
// macOS gets a black and a white mark per status (the image carries colour, so
// it cannot be a template image); Linux reuses the white PNGs; Windows gets one
// multi-size ICO per status.
import AppKit

struct Status {
  let name: String
  let rgb: (CGFloat, CGFloat, CGFloat)
}

// Names match SystemTrayStatus in module_desktop_core.
let statuses = [
  Status(name: "connected", rgb: (0x34, 0xC7, 0x59)),
  Status(name: "connecting", rgb: (0xFF, 0x9F, 0x0A)),
  Status(name: "off", rgb: (0x8E, 0x8E, 0x93)),
  Status(name: "failed", rgb: (0xFF, 0x3B, 0x30)),
]

// Geometry in the SVG's 24-unit view box: a dot a third of the mark's width,
// with a thin transparent gap between it and the mark.
let viewBox: CGFloat = 24
let dotRadius: CGFloat = 4
let dotCenter = CGPoint(x: 20, y: 4)  // bottom-right in AppKit's bottom-up coordinates
let knockoutGap: CGFloat = 1.25

let pngSize = 64
let icoSizes = [16, 24, 32, 48, 64, 256]

guard let mark = NSImage(contentsOfFile: "assets/tray_icon.svg") else {
  fatalError("Run from client/desktop: assets/tray_icon.svg not found")
}

func color(_ rgb: (CGFloat, CGFloat, CGFloat)) -> NSColor {
  NSColor(srgbRed: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
}

func render(status: Status, mark shade: NSColor, size: Int) -> Data {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    fatalError("Unable to create a \(size)px bitmap")
  }
  // One point per pixel, like the original asset.
  bitmap.size = NSSize(width: size, height: size)
  let scale = CGFloat(size) / viewBox
  let canvas = NSRect(x: 0, y: 0, width: size, height: size)

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.imageInterpolation = .high
  mark.draw(in: canvas)
  shade.setFill()
  canvas.fill(using: .sourceIn)

  func circle(radius: CGFloat) -> NSBezierPath {
    let r = radius * scale
    return NSBezierPath(
      ovalIn: NSRect(x: dotCenter.x * scale - r, y: dotCenter.y * scale - r, width: r * 2, height: r * 2))
  }
  context.compositingOperation = .clear
  circle(radius: dotRadius + knockoutGap).fill()
  context.compositingOperation = .sourceOver
  color(status.rgb).setFill()
  circle(radius: dotRadius).fill()
  context.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()

  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode a \(size)px PNG")
  }
  return png
}

// An ICO whose entries are embedded PNGs, smallest first.
func ico(images: [(size: Int, png: Data)]) -> Data {
  var data = Data()
  func append<T: FixedWidthInteger>(_ value: T) {
    withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
  }
  append(UInt16(0))
  append(UInt16(1))
  append(UInt16(images.count))
  var offset = 6 + 16 * images.count
  for image in images {
    data.append(UInt8(image.size >= 256 ? 0 : image.size))
    data.append(UInt8(image.size >= 256 ? 0 : image.size))
    data.append(0)  // palette
    data.append(0)  // reserved
    append(UInt16(1))  // colour planes
    append(UInt16(32))  // bits per pixel
    append(UInt32(image.png.count))
    append(UInt32(offset))
    offset += image.png.count
  }
  for image in images {
    data.append(image.png)
  }
  return data
}

let output = URL(fileURLWithPath: "assets/tray", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for status in statuses {
  for (shadeName, shade) in [("black", NSColor.black), ("white", NSColor.white)] {
    try render(status: status, mark: shade, size: pngSize)
      .write(to: output.appendingPathComponent("tray_icon_\(status.name)_\(shadeName).png"))
  }
  let entries = icoSizes.map { (size: $0, png: render(status: status, mark: .white, size: $0)) }
  try ico(images: entries).write(to: output.appendingPathComponent("tray_icon_\(status.name).ico"))
}
print("Wrote \(statuses.count * 3) tray icons to assets/tray/")
