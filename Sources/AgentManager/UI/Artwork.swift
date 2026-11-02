import AppKit
import SwiftUI

enum AgentArtwork {
    private static var cache: [Agent: NSImage] = [:]

    static func image(for agent: Agent) -> NSImage {
        if let cached = cache[agent] { return cached }
        let bundleID: String
        let assetName: String
        switch agent {
        case .claude: bundleID = "com.anthropic.claudefordesktop"; assetName = "claude_code"
        case .codex: bundleID = "com.openai.codex"; assetName = "codex"
        case .cursor: bundleID = "com.todesktop.230313mzl4w4u92"; assetName = "cursor"
        case .antigravity: bundleID = "com.google.antigravity"; assetName = "antigravity"
        case .qoder: bundleID = "com.qoder.app"; assetName = "qoder"
        case .workbuddy: bundleID = "com.workbuddy.workbuddy"; assetName = "workbuddy"
        }
        let image: NSImage
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: app.path)
        } else {
            image = bundledIcon(named: assetName)
                ?? NSImage(systemSymbolName: agent.icon, accessibilityDescription: agent.rawValue)
                ?? NSImage()
        }
        cache[agent] = image
        return image
    }

    private static func bundledIcon(named name: String) -> NSImage? {
        for ext in ["png", "svg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "AgentIcons"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            let local = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/AgentIcons/\(name).\(ext)")
            if let image = NSImage(contentsOf: local) { return image }
        }
        return nil
    }

    static func appIcon() -> NSImage {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns") {
            return NSImage(contentsOfFile: path) ?? NSImage()
        }
        let path = FileManager.default.currentDirectoryPath + "/Resources/AppIcon/AppIcon.png"
        return NSImage(contentsOfFile: path) ?? NSImage()
    }
}

struct AgentLogo: View {
    let agent: Agent
    let size: CGFloat
    var body: some View {
        Image(nsImage: AgentArtwork.image(for: agent))
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(agent.rawValue)
    }
}
