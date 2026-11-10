// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "SpeechCore", targets: ["SpeechCore"])],
    targets: [
        .target(name: "SpeechCore"),
        .testTarget(name: "SpeechCoreTests", dependencies: ["SpeechCore"])
    ]
)
