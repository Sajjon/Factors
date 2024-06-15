// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Factor",
	platforms: [.macOS(.v10_15), .iOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Factor",
            targets: ["Factor"]),
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-testing", from: "0.10.0"),
		.package(url: "https://github.com/apple/swift-collections", from: "1.1.1"),
		.package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.0.2"),
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
			name: "Factor", dependencies: [
				.product(name: "Collections", package: "swift-collections"),
				.product(name: "IdentifiedCollections", package: "swift-identified-collections")
			]),
        .testTarget(
            name: "FactorTests",
			dependencies: ["Factor", .product(name: "Testing", package: "swift-testing")]),
    ]
)
