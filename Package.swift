// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "GlideMouse", defaultLocalization: "en", platforms: [.macOS(.v14)],
    products: [.executable(name: "GlideMouse", targets: ["GlideMouse"]), .library(name: "MouseCore", targets: ["MouseCore"]), .library(name: "NativeBridge", targets: ["NativeBridge"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "MouseCore"),
        .target(name: "NativeBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("CoreFoundation")]),
        .executableTarget(name: "GlideMouse", dependencies: ["MouseCore", "NativeBridge", .product(name: "Sparkle", package: "Sparkle")], resources: [.process("Resources")]),
        .testTarget(name: "MouseCoreTests", dependencies: ["MouseCore", "NativeBridge"], resources: [.copy("Fixtures")])
    ], swiftLanguageModes: [.v6]
)
