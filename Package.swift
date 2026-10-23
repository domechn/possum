// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Possum",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Possum",
            path: "Sources/Possum"
        ),
        .testTarget(
            name: "PossumTests",
            dependencies: ["Possum"],
            path: "Tests/PossumTests"
        )
    ]
)
