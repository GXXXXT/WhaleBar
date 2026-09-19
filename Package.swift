// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhaleBar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "WhaleBar", targets: ["WhaleBar"])
    ],
    targets: [
        .target(name: "WhaleBarKit"),
        .executableTarget(
            name: "WhaleBar",
            dependencies: ["WhaleBarKit"]
        ),
        // 本机仅有 Command Line Tools（无 XCTest / Swift Testing 运行时），
        // 测试以自研断言检查器承载：swift run WhaleBarKitChecks
        .executableTarget(
            name: "WhaleBarKitChecks",
            dependencies: ["WhaleBarKit"],
            path: "Checks/WhaleBarKitChecks"
        ),
    ]
)
