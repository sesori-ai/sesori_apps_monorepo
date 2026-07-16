// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "theme_prego",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "theme-prego", targets: ["theme_prego"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "theme_prego",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
