// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "frida-ios-dump-swift",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .executable(
            name: "frida-ios-dump",
            targets: ["FridaiOSDump"]
        ),
    ],
    dependencies: [
        .package(path: "../frida-swift"),
    ],
    targets: [
        .executableTarget(
            name: "FridaiOSDump",
            dependencies: [
                .product(name: "Frida", package: "frida-swift"),
            ],
            path: "Sources/FridaiOSDump",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "FridaiOSDumpTests",
            dependencies: ["FridaiOSDump"],
            path: "Tests/FridaiOSDumpTests"
        ),
    ]
)
