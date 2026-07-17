// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localXcframeworkPath = packageDir.appendingPathComponent("isar.xcframework").path
let useLocalBinary = FileManager.default.fileExists(atPath: localXcframeworkPath)

// Keep in sync with packages/isar_community version / binaries CDN.
let isarVersion = "3.3.2"
let isarIosChecksum = "06253a6b25cb8378820bd218ec68a55c8c7c626304137fa30b0691aee13ce366"

let isarTarget: Target = useLocalBinary
    ? .binaryTarget(name: "isar", path: "isar.xcframework")
    : .binaryTarget(
        name: "isar",
        url: "https://binaries.isar-community.dev/\(isarVersion)/isar_ios.xcframework.zip",
        checksum: isarIosChecksum
    )

let package = Package(
    name: "isar_community_flutter_libs",
    platforms: [
        .iOS("13.0")
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
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
