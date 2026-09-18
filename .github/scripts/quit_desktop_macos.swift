import AppKit
import ApplicationServices

private let quitTitle = "Quit Sesori"
private let quitSelectionKeyCode: CGKeyCode = 12 // ANSI Q
private let lastMenuItemKeyCode: CGKeyCode = 126 // Up Arrow selects the final item from no selection.
private let escapeKeyCode: CGKeyCode = 53

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

private func frame(of element: AXUIElement) -> CGRect? {
    guard let positionReference = attribute(element, kAXPositionAttribute as CFString),
          let sizeReference = attribute(element, kAXSizeAttribute as CFString),
          CFGetTypeID(positionReference) == AXValueGetTypeID(),
          CFGetTypeID(sizeReference) == AXValueGetTypeID() else {
        return nil
    }
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionReference as! AXValue, .cgPoint, &position),
          AXValueGetValue(sizeReference as! AXValue, .cgSize, &size) else {
        return nil
    }
    return CGRect(origin: position, size: size)
}

private func isAnchored(_ menu: AXUIElement, to statusFrame: CGRect) -> Bool {
    guard let menuFrame = frame(of: menu),
          menuFrame.width > 0,
          menuFrame.height > 0 else {
        return false
    }
    let tolerance: CGFloat = 16
    let containsStatusCenter = menuFrame.minX - tolerance <= statusFrame.midX
        && statusFrame.midX <= menuFrame.maxX + tolerance
    let verticalEdgeDistance = min(
        abs(menuFrame.minY - statusFrame.maxY),
        abs(menuFrame.maxY - statusFrame.minY)
    )
    return containsStatusCenter && verticalEdgeDistance <= max(32, statusFrame.height + tolerance)
}

private func postKey(_ keyCode: CGKeyCode) -> Bool {
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
        return false
    }
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    return true
}

private func focusedElement() -> AXUIElement? {
    elements(attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString)).first
}

private func focusedQuitItem(
    _ item: AXUIElement,
    ownedBy pid: pid_t,
    anchoredTo statusFrame: CGRect
) -> AXUIElement? {
    guard processIdentifier(item) == pid,
          stringAttribute(item, kAXRoleAttribute as CFString) == kAXMenuItemRole,
          stringAttribute(item, kAXTitleAttribute as CFString) == quitTitle,
          let menu = elements(attribute(item, kAXParentAttribute as CFString)).first,
          processIdentifier(menu) == pid,
          stringAttribute(menu, kAXRoleAttribute as CFString) == kAXMenuRole,
          isAnchored(menu, to: statusFrame) else {
        return nil
    }
    return item
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
    guard let statusFrame = frame(of: statusItem) else {
        print("STATUS_ITEM \(index) has no accessible frame")
        continue
    }
    // tray_manager opens its context menu from the icon mouse-down callback. AXPress
    // follows that real click path; AXShowMenu may bypass the callback because the
    // plugin does not attach its menu directly to the NSStatusItem.
    let action = actions.contains(kAXPressAction) ? kAXPressAction : kAXShowMenuAction
    guard actions.contains(action), AXUIElementPerformAction(statusItem, action as CFString) == .success else {
        print("STATUS_ITEM \(index) could not perform \(action)")
        continue
    }
    // tray_manager's transient menu is not exposed as a status-item child. Type-select
    // its exact Quit title, then accept only the focused process-owned menu item whose
    // parent menu is spatially anchored to the status item that received AXPress.
    Thread.sleep(forTimeInterval: 0.5)
    for attempt in 0..<100 {
        if attempt < 50, attempt.isMultiple(of: 10) {
            guard postKey(quitSelectionKeyCode) else {
                fail("Could not post the Quit type-selection key")
            }
        } else if attempt == 50 {
            guard postKey(lastMenuItemKeyCode) else {
                fail("Could not post the final-item selection key")
            }
        }
        if let focused = focusedElement() {
            if attempt.isMultiple(of: 10) {
                print("FOCUSED \(description(focused))")
            }
            if let quitItem = focusedQuitItem(focused, ownedBy: pid, anchoredTo: statusFrame) {
                print("QUIT_ITEM \(description(quitItem))")
                if AXUIElementPerformAction(quitItem, kAXPressAction as CFString) == .success {
                    print("PASS invoked the focused Sesori tray Quit command")
                    exit(0)
                }
            }
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    if !postKey(escapeKeyCode) {
        print("STATUS_ITEM \(index) could not dismiss its unrecognized menu")
    }
}

fail("Could not find or invoke the accessible Quit Sesori tray item")
