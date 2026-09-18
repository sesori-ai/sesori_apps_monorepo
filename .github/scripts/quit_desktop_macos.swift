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
    let all = elements(attribute(element, kAXChildrenAttribute as CFString))
    return visible + all
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

private func processIdentifier(_ element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else {
        return nil
    }
    return pid
}

private func description(_ element: AXUIElement) -> String {
    let attributes = [
        "role=\(stringAttribute(element, kAXRoleAttribute as CFString) ?? "<none>")",
        "subrole=\(stringAttribute(element, kAXSubroleAttribute as CFString) ?? "<none>")",
        "title=\(stringAttribute(element, kAXTitleAttribute as CFString) ?? "<none>")",
        "description=\(stringAttribute(element, kAXDescriptionAttribute as CFString) ?? "<none>")",
        "identifier=\(stringAttribute(element, kAXIdentifierAttribute as CFString) ?? "<none>")",
        "actions=\(actionNames(element).joined(separator: ","))",
    ]
    return attributes.joined(separator: " ")
}

private func findQuitItem(from roots: [AXUIElement]) -> AXUIElement? {
    var queue = roots
    var visited: [AXUIElement] = []
    while !queue.isEmpty && visited.count < 1_024 {
        let element = queue.removeFirst()
        if visited.contains(where: { CFEqual($0, element) }) {
            continue
        }
        visited.append(element)
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
let statusItems = children(extras).filter { processIdentifier($0) == pid }
guard !statusItems.isEmpty else {
    fail("Sesori has no process-owned accessible status item")
}

for (index, statusItem) in statusItems.enumerated() {
    print("STATUS_ITEM \(index) \(description(statusItem))")
    let actions = actionNames(statusItem)
    // tray_manager opens its context menu from the icon mouse-down callback. AXPress
    // follows that real click path; AXShowMenu may bypass the callback because the
    // plugin does not attach its menu directly to the NSStatusItem.
    let action = actions.contains(kAXPressAction) ? kAXPressAction : kAXShowMenuAction
    guard actions.contains(action), AXUIElementPerformAction(statusItem, action as CFString) == .success else {
        print("STATUS_ITEM \(index) could not perform \(action)")
        continue
    }
    for _ in 0..<100 {
        if let quitItem = findQuitItem(from: [statusItem, extras, appElement]) {
            print("QUIT_ITEM \(description(quitItem))")
            if AXUIElementPerformAction(quitItem, kAXPressAction as CFString) == .success {
                print("PASS invoked the accessible Sesori tray Quit command")
                exit(0)
            }
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

fail("Could not find or invoke the accessible Quit Sesori tray item")
