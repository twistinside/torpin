// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TorpinServiceLambda",
    platforms: [
        .macOS(.v15)
      ],
    products: [
        .executable(name: "TorpinServiceLambda", targets: ["TorpinServiceLambda"]),
        .executable(name: "EventHandlerLambda", targets: ["EventHandlerLambda"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.1"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha")
    ],
    targets: [
        .executableTarget(
            name: "TorpinServiceLambda",
            dependencies: [
                "Common",
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "Sources/APILambda"
        ),
        .executableTarget(
            name: "EventHandlerLambda",
            dependencies: [
                "Common",
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "Sources/EventHandlerLambda"
        ),
        .target(
            name: "Common",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "Sources/Common"
        )
    ]
)
