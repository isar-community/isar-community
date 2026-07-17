// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Always use a remote binaryTarget. Flutter copies this package into
// ios/Flutter/ephemeral/Packages without the vendored xcframework, so a local
// path binaryTarget fails for app builds (including path/git dependencies).
let isarVersion = "3.3.2"
let isarIosChecksum = "06253a6b25cb8378820bd218ec68a55c8c7c626304137fa30b0691aee13ce366"

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
        .binaryTarget(
            name: "isar",
            url: "https://binaries.isar-community.dev/\(isarVersion)/isar_ios.xcframework.zip",
            checksum: isarIosChecksum
        ),
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
