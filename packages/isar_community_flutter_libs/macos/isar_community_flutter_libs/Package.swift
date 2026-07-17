// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
        .binaryTarget(
            name: "isar",
            path: "isar.xcframework"
        ),
        .target(
            name: "isar_community_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "isar",
            ]
        ),
    ]
)
