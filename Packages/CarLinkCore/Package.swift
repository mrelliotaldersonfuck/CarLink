// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CarLinkCore",
    platforms: [.iOS("18.0"), .macOS(.v13)],
    products: [.library(name: "CarLinkCore", targets: ["CarLinkCore"])],
    targets: [
        .target(name: "CarLinkCore"),
        .testTarget(name: "CarLinkCoreTests", dependencies: ["CarLinkCore"])
    ]
)
