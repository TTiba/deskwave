// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeskWeaveMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "DeskWeaveMac", targets: ["DeskWeaveMac"]),
        .executable(name: "VirtualDisplayProbe", targets: ["VirtualDisplayProbe"])
    ],
    targets: [
        .target(
            name: "VirtualDisplayBridge",
            path: "Sources/VirtualDisplayBridge",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fobjc-arc"])
            ],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "DeskWeaveMac",
            dependencies: ["VirtualDisplayBridge"],
            path: "Sources/DeskWeaveMac",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Network"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("VideoToolbox")
            ]
        ),
        .executableTarget(
            name: "VirtualDisplayProbe",
            dependencies: ["VirtualDisplayBridge"],
            path: "Sources/VirtualDisplayProbe"
        ),
        .testTarget(
            name: "VirtualDisplayBridgeTests",
            dependencies: ["VirtualDisplayBridge"],
            path: "Tests/VirtualDisplayBridgeTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
