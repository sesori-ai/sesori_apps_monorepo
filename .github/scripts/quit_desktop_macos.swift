import AppKit
import ApplicationServices

private let quitTitle = "Quit Sesori"

private func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

private func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
        return nil
    }
    return value
}

private func elements(_ value: CFTypeRef?) -> [AXUIElement] {
    guard let value else { return [] }
    if CFGetTypeID(value) == AXUIElementGetTypeID() {
        return [value as! AXUIElement]
    }
    return value as? [AXUIElement] ?? []
}

private func children(_ element: AXUIElement) -> [AXUIElement] {
    let visible = elements(attribute(element, kAXVisibleChildrenAttribute as CFString))
    return visible.isEmpty ? elements(attribute(element, kAXChildrenAttribute as CFString)) : visible
}

private func stringAttribute(_ element: AXUIElement, _ name: CFString) -> String? {
    attribute(element, name) as? String
}

private func actionNames(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success else {
        return []
    }
    return names as? [String] ?? []
}

private func findQuitItem(from root: AXUIElement) -> AXUIElement? {
    var queue = [root]
    var visited = 0
    while !queue.isEmpty && visited < 256 {
        let element = queue.removeFirst()
        visited += 1
        if stringAttribute(element, kAXRoleAttribute as CFString) == kAXMenuItemRole,
           stringAttribute(element, kAXTitleAttribute as CFString) == quitTitle {
            return element
        }
        queue.append(contentsOf: children(element))
    }
    return nil
}

guard CommandLine.arguments.count == 2, let pid = pid_t(CommandLine.arguments[1]) else {
    fail("Usage: quit_desktop_macos <pid>")
}
guard AXIsProcessTrusted() else {
    fail("BLOCKED: Accessibility is not trusted on this native runner", code: 2)
}
guard let application = NSRunningApplication(processIdentifier: pid),
      application.bundleIdentifier == "com.sesori.desktop" else {
    fail("Refusing to control a process that is not com.sesori.desktop")
}

let appElement = AXUIElementCreateApplication(pid)
guard let extras = elements(attribute(appElement, kAXExtrasMenuBarAttribute as CFString)).first else {
    fail("Sesori has no accessible status-item menu bar")
}
let statusItems = children(extras)
guard !statusItems.isEmpty else {
    fail("Sesori has no accessible status item")
}

for statusItem in statusItems {
    let actions = actionNames(statusItem)
    let action = actions.contains(kAXShowMenuAction) ? kAXShowMenuAction : kAXPressAction
    guard AXUIElementPerformAction(statusItem, action as CFString) == .success else {
        continue
    }
    for _ in 0..<50 {
        if let quitItem = findQuitItem(from: statusItem),
           AXUIElementPerformAction(quitItem, kAXPressAction as CFString) == .success {
            print("PASS invoked the accessible Sesori tray Quit command")
            exit(0)
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

fail("Could not find or invoke the accessible Quit Sesori tray item")
