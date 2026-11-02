import AppKit
import SwiftUI

private final class AgentManagerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private final class MainWindowLifecycle: NSObject {
    static let shared = MainWindowLifecycle()

    private weak var mainWindow: NSWindow?

    func attach(_ window: NSWindow) {
        guard mainWindow !== window else { return }
        if let previous = mainWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: previous)
        }
        mainWindow = window
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: window)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    @objc private func mainWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, mainWindow === window else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        mainWindow = nil
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

private final class MainWindowTrackingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { MainWindowLifecycle.shared.attach(window) }
    }
}

private struct MainWindowTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowTrackingView { MainWindowTrackingView() }
    func updateNSView(_ view: MainWindowTrackingView, context: Context) {}
}

private struct StatusBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开主界面") {
            openWindow(id: "main")
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("退出 Looma") {
            NSApplication.shared.terminate(nil)
        }
    }
}

@main struct AgentManagerApp: App {
    @NSApplicationDelegateAdaptor(AgentManagerAppDelegate.self) private var appDelegate

    // A monochrome cat head matching the app mascot. Template rendering lets
    // macOS choose the appropriate contrast for the current menu bar.
    private static let menuBarIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let head = NSBezierPath()
            head.move(to: NSPoint(x: 3, y: 9))
            head.line(to: NSPoint(x: 3, y: 16))
            head.curve(to: NSPoint(x: 7, y: 13), controlPoint1: NSPoint(x: 4, y: 16), controlPoint2: NSPoint(x: 6, y: 14))
            head.curve(to: NSPoint(x: 13, y: 13), controlPoint1: NSPoint(x: 9, y: 14), controlPoint2: NSPoint(x: 11, y: 14))
            head.curve(to: NSPoint(x: 17, y: 16), controlPoint1: NSPoint(x: 14, y: 14), controlPoint2: NSPoint(x: 16, y: 16))
            head.line(to: NSPoint(x: 17, y: 9))
            head.curve(to: NSPoint(x: 10, y: 2), controlPoint1: NSPoint(x: 18, y: 4), controlPoint2: NSPoint(x: 14, y: 2))
            head.curve(to: NSPoint(x: 3, y: 9), controlPoint1: NSPoint(x: 6, y: 2), controlPoint2: NSPoint(x: 2, y: 4))
            head.close()
            head.lineWidth = 1.4
            head.lineJoinStyle = .round
            head.stroke()
            for x in [6.0, 12.0] {
                NSBezierPath(ovalIn: NSRect(x: x, y: 7.5, width: 2, height: 3)).fill()
            }
            let face = NSBezierPath()
            face.move(to: NSPoint(x: 9, y: 6.5))
            face.line(to: NSPoint(x: 10, y: 5.5))
            face.line(to: NSPoint(x: 11, y: 6.5))
            face.move(to: NSPoint(x: 1, y: 7))
            face.line(to: NSPoint(x: 5, y: 6))
            face.move(to: NSPoint(x: 15, y: 6))
            face.line(to: NSPoint(x: 19, y: 7))
            face.lineWidth = 1
            face.lineCapStyle = .round
            face.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()

    var body: some Scene {
        Window("Looma", id: "main") {
            ManagerRoot()
                .frame(minWidth: 1080, minHeight: 720)
                .background(MainWindowTracker())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1300, height: 840)

        MenuBarExtra {
            StatusBarMenu()
        } label: {
            Image(nsImage: Self.menuBarIcon)
                .accessibilityLabel("Looma")
        }
        .menuBarExtraStyle(.menu)
    }
}
