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

private func descendants(from root: AXUIElement) -> [AXUIElement] {
    var queue = [root]
    var visited: [AXUIElement] = []
    while !queue.isEmpty && visited.count < 256 {
        let element = queue.removeFirst()
        if visited.contains(where: { CFEqual($0, element) }) {
            continue
        }
        visited.append(element)
        queue.append(contentsOf: children(element))
    }
    return visited
}

private func quitItem(in menu: AXUIElement, ownedBy pid: pid_t) -> AXUIElement? {
    descendants(from: menu).first {
        processIdentifier($0) == pid
            && stringAttribute($0, kAXRoleAttribute as CFString) == kAXMenuItemRole
            && stringAttribute($0, kAXTitleAttribute as CFString) == quitTitle
    }
}

private func hitTest(at point: CGPoint) -> AXUIElement? {
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(
        AXUIElementCreateSystemWide(),
        Float(point.x),
        Float(point.y),
        &element
    ) == .success else {
        return nil
    }
    return element
}

private func anchoredMenu(
    containing element: AXUIElement,
    ownedBy pid: pid_t,
    anchoredTo statusFrame: CGRect
) -> AXUIElement? {
    var current: AXUIElement? = element
    for _ in 0..<8 {
        guard let candidate = current else {
            return nil
        }
        if processIdentifier(candidate) == pid,
           stringAttribute(candidate, kAXRoleAttribute as CFString) == kAXMenuRole,
           isAnchored(candidate, to: statusFrame) {
            return candidate
        }
        current = elements(attribute(candidate, kAXParentAttribute as CFString)).first
    }
    return nil
}

private func visibleTrayMenu(
    ownedBy pid: pid_t,
    anchoredTo statusFrame: CGRect,
    reportHits: Bool
) -> AXUIElement? {
    let offsets: [CGFloat] = [6, 18, 30, 50, 74]
    for offset in offsets {
        let points = [
            CGPoint(x: statusFrame.midX, y: statusFrame.maxY + offset),
            CGPoint(x: statusFrame.midX, y: statusFrame.minY - offset),
        ]
        for point in points {
            let element = hitTest(at: point)
            if reportHits {
                let result = element.map(description) ?? "<none>"
                print("HIT_TEST x=\(point.x) y=\(point.y) \(result)")
            }
            guard let element,
                  let menu = anchoredMenu(
                    containing: element,
                    ownedBy: pid,
                    anchoredTo: statusFrame
                  ) else {
                continue
            }
            return menu
        }
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
    guard let statusFrame = frame(of: statusItem) else {
        print("STATUS_ITEM \(index) has no accessible frame")
        continue
    }
    print("STATUS_FRAME \(index) x=\(statusFrame.minX) y=\(statusFrame.minY) "
        + "width=\(statusFrame.width) height=\(statusFrame.height)")
    // tray_manager opens its context menu from the icon mouse-down callback. Require
    // AXPress because AXShowMenu can bypass that callback for this custom status item.
    guard actions.contains(kAXPressAction),
          AXUIElementPerformAction(statusItem, kAXPressAction as CFString) == .success else {
        print("STATUS_ITEM \(index) could not perform AXPress")
        continue
    }
    // tray_manager's transient menu is not exposed as a status-item child. Hit-test
    // immediately beside the clicked item's frame, accept only an anchored process-owned
    // AXMenu reached at that visible screen location, then search only inside that menu.
    for attempt in 0..<100 {
        if let trayMenu = visibleTrayMenu(
            ownedBy: pid,
            anchoredTo: statusFrame,
            reportHits: attempt == 0 || attempt == 50
        ), let quitItem = quitItem(in: trayMenu, ownedBy: pid) {
            print("TRAY_MENU \(description(trayMenu))")
            print("QUIT_ITEM \(description(quitItem))")
            if AXUIElementPerformAction(quitItem, kAXPressAction as CFString) == .success {
                print("PASS invoked the hit-tested Sesori tray Quit command")
                exit(0)
            }
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

fail("Could not find or invoke the accessible Quit Sesori tray item")
