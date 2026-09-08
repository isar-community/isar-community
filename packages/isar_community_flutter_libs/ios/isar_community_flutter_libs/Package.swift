// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "isar_community_flutter_libs",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "isar-community-flutter-libs", targets: ["isar_community_flutter_libs"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "isar_community_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .target(name: "isar_symbols"),
            ],
            path: "Sources/isar_community_flutter_libs",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .target(
            name: "isar_symbols",
            dependencies: [
                .target(name: "isar"),
            ],
            path: "Sources/isar_symbols",
            publicHeadersPath: "include"
        ),
        .binaryTarget(
            name: "isar",
            path: "isar.xcframework"
        ),
    ]
)
