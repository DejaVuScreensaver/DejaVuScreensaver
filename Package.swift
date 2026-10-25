// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DejaVuScreensaver",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DejaVuScreensaver", targets: ["DejaVuScreensaver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .executableTarget(
            name: "DejaVuScreensaver",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/DejaVuScreensaver",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("MapKit"),
                .linkedFramework("Photos"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("dl"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
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
