// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Peer2ParkNetworking",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Peer2ParkNetworking",
            targets: ["Peer2ParkNetworking"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Peer2ParkNetworking"),
        .testTarget(
            name: "Peer2ParkNetworkingTests",
            dependencies: ["Peer2ParkNetworking"]
        ),
    ]
)
