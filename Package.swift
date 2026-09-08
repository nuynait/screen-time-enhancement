// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GateCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "GateCore", path: "Core"),
        .testTarget(name: "GateCoreTests", dependencies: ["GateCore"], path: "Tests")
    ]
)
