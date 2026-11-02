// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenEdgeBarKit",
    // Liquid Glass needs macOS 26; earlier versions get a frosted look instead.
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EdgeBarCore", targets: ["EdgeBarCore"]),
        .library(name: "EdgeBarSystem", targets: ["EdgeBarSystem"]),
        .library(name: "EdgeBarUI", targets: ["EdgeBarUI"]),
    ],
    targets: [
        // Pure gesture logic. No AppKit, no hardware.
        .target(name: "EdgeBarCore"),
        // C declarations for the private MultitouchSupport framework.
        .target(name: "CMultitouch"),
        // Talks to macOS: trackpad, media keys, audio, display, haptics, cursor.
        .target(name: "EdgeBarSystem", dependencies: ["EdgeBarCore", "CMultitouch"]),
        // The menu bar window, the settings and the welcome tour.
        .target(name: "EdgeBarUI", dependencies: ["EdgeBarCore", "EdgeBarSystem"]),
    ]
)
