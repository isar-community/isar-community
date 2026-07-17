// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localInfoPlist = packageDir
    .appendingPathComponent("isar.xcframework")
    .appendingPathComponent("Info.plist")
    .path
// Require a real xcframework (Info.plist), not an empty directory Flutter may leave behind.
let useLocalBinary = FileManager.default.fileExists(atPath: localInfoPlist)

// Keep in sync with packages/isar_community version / binaries CDN.
let isarVersion = "3.3.2"
let isarMacosChecksum = "d146141ef2af2684ab62c5ebedc6b5d05879e9428c3225310cafc66d2d44f5a7"

let isarTarget: Target = useLocalBinary
    ? .binaryTarget(name: "isar", path: "isar.xcframework")
    : .binaryTarget(
        name: "isar",
        url: "https://binaries.isar-community.dev/\(isarVersion)/isar_macos.xcframework.zip",
        checksum: isarMacosChecksum
    )

let package = Package(
    name: "isar_community_flutter_libs",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "isar-community-flutter-libs", targets: ["isar_community_flutter_libs"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        isarTarget,
        .target(
            name: "isar_community_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "isar",
            ]
        ),
    ]
)
