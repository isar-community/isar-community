// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "isar_community_flutter_libs",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "isar-community-flutter-libs", targets: ["isar_community_flutter_libs"]),
    ],
    targets: [
        .target(
            name: "isar_community_flutter_libs",
            dependencies: [
                .target(name: "isar"),
            ],
            path: "Sources/isar_community_flutter_libs",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .binaryTarget(
            name: "isar",
            path: "isar.xcframework"
        ),
    ]
)
