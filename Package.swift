// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HazeFocus",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "HazeFocus", targets: ["HazeFocus"])],
    targets: [
        .target(name: "FocusCore"),
        .executableTarget(name: "HazeFocus", dependencies: ["FocusCore"],
                          linkerSettings: [.linkedFramework("Carbon")]),
        .testTarget(name: "FocusCoreTests", dependencies: ["FocusCore"])
    ]
)
