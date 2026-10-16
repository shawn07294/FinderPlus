// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FinderPlus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FinderPlus",
            targets: ["FinderPlus"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FinderPlus",
            dependencies: [],
            path: "Sources/FinderPlus"
        )
    ]
)
