// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MCPUtils",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MCPUtils", targets: ["MCPUtils"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MCPUtils",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/MCPUtils"
        )
    ]
)
