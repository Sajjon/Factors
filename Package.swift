// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Factor",
	platforms: [.macOS(.v10_14), .iOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Factor",
            targets: ["Factor"]),
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-collections", from: "1.1.1"),
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
			name: "Factor", dependencies: [
				.product(name: "Collections", package: "swift-collections")
			]),
        .testTarget(
            name: "FactorTests",
            dependencies: ["Factor"]),
    ]
)
