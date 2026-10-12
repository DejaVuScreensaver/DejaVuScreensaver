// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DejaVuScreensaver",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DejaVuScreensaver", targets: ["DejaVuScreensaver"]),
    ],
    targets: [
        .executableTarget(
            name: "DejaVuScreensaver",
            path: "Sources/DejaVuScreensaver",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("MapKit"),
                .linkedFramework("Photos"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("dl"),
            ]
        ),
        .testTarget(
            name: "DejaVuScreensaverTests",
            dependencies: ["DejaVuScreensaver"],
            path: "Tests/DejaVuScreensaverTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
