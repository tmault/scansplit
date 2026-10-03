// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScanSplit",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ScanSplit", targets: ["ScanSplit"])],
    targets: [
        .target(name: "ScanSplitCore"),
        .executableTarget(name: "ScanSplit", dependencies: ["ScanSplitCore"]),
        .testTarget(name: "ScanSplitCoreTests", dependencies: ["ScanSplitCore"]),
        .testTarget(name: "ScanSplitAppTests", dependencies: ["ScanSplit", "ScanSplitCore"])
    ]
)
