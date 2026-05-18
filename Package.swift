// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GTNW",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    products: [
        // Executable app product
        .executable(
            name: "GTNW",
            targets: ["GTNW"])
    ],
    targets: [
        .executableTarget(
            name: "GTNW",
            path: "Shared",
            resources: [.process("Assets.xcassets")])
    ]

