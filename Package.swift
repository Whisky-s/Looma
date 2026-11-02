// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Looma",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Looma", targets: ["AgentManager"])],
    targets: [.executableTarget(name: "AgentManager", path: "Sources/AgentManager")]
)
