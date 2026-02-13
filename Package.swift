// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LobsMissionControl",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "lobs-mission-control", targets: ["LobsMissionControl"])
  ],
  targets: [
    .executableTarget(
      name: "LobsMissionControl",
      path: "Sources/LobsMissionControl",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "LobsMissionControlTests",
      dependencies: ["LobsMissionControl"],
      path: "Tests/LobsMissionControlTests"
    )
  ]
)
