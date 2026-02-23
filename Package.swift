// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LobsMissionControl",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "lobs-mission-control", targets: ["LobsMissionControl"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/swift-server/async-http-client", from: "1.9.0")
  ],
  targets: [
    .executableTarget(
      name: "LobsMissionControl",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
      ],
      path: "Sources/LobsMissionControl",
      resources: [
        .process("Resources")
      ],
      plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
    ),
    .testTarget(
      name: "LobsMissionControlTests",
      dependencies: ["LobsMissionControl"],
      path: "Tests/LobsMissionControlTests"
    )
  ]
)
