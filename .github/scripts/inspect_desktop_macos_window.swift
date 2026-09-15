import AppKit
import ApplicationServices
import CoreGraphics

// Read-only native window evidence for one process launched by the CI driver.
let screenCount = NSScreen.screens.count
print("SCREEN_COUNT \(screenCount)")
print("ACCESSIBILITY_TRUSTED \(AXIsProcessTrusted())")
guard screenCount > 0 else { exit(2) }
if CommandLine.arguments.count == 1 { exit(0) }
let processID = Int32(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
for window in windows {
    guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processID,
          (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: NSNumber],
          let width = bounds["Width"]?.doubleValue, let height = bounds["Height"]?.doubleValue,
          width >= 500, height >= 300,
          let number = window[kCGWindowNumber as String] as? NSNumber else { continue }
    print("WINDOW_ID \(number.uint32Value)")
    print("WINDOW_SIZE \(width)x\(height)")
    exit(0)
}
fputs("No visible main window for the owned desktop process\n", stderr)
exit(1)
