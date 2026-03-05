// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LazyflowUI",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "LazyflowUI", targets: ["LazyflowUI"]),
    ],
    dependencies: [
        .package(path: "../LazyflowCore"),
    ],
    targets: [
        .target(
            name: "LazyflowUI",
            dependencies: ["LazyflowCore"]
        ),
    ]
)
