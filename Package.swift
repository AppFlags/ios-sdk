// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppFlags",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AppFlags",
            targets: ["AppFlags"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AppFlags/AppFlagsSwiftProtobufs.git", exact: "1.0.0"),
        .package(url: "https://github.com/LaunchDarkly/swift-eventsource.git", .upToNextMajor(from: "3.1.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AppFlags",
            dependencies: [
                .product(name: "AppFlagsSwiftProtobufs", package: "AppFlagsSwiftProtobufs"),
                .product(name: "LDSwiftEventSource", package: "swift-eventsource")
            ]
        ),
        .testTarget(
            name: "AppFlagsTests",
            dependencies: ["AppFlags"]),
    ]
)
