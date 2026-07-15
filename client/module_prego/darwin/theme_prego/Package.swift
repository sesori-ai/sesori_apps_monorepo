// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "theme_prego",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "theme-prego", targets: ["theme_prego"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "theme_prego",
      dependencies: []
    )
  ]
)
