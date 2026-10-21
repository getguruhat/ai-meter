// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AI Meter",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "AIMeter", path: "Sources")]
)
