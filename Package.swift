// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommvaultSaaS",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CommvaultSaaS",
            targets: ["CommvaultSaaS"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CommvaultSaaS",
            dependencies: [],
            path: "CommvaultSaaS"
        ),
    ]
)
