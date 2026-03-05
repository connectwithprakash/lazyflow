// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LazyflowCore",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "LazyflowCore", targets: ["LazyflowCore"]),
    ],
    targets: [
        .target(name: "LazyflowCore"),
    ]
)
