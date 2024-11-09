// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TorpinServiceLambda",
    platforms: [
        .macOS(.v15)
      ],
    products: [
        .executable(name: "TorpinServiceLambda", targets: ["TorpinServiceLambda"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.1")
    ],
    targets: [
        .executableTarget(
            name: "TorpinServiceLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ],
            path: "Sources"
        )
    ]
)
