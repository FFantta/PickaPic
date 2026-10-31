// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PickaPicCore", platforms: [.macOS(.v13), .iOS(.v16)], products: [.library(name: "PickaPicCore", targets: ["PickaPicCore"])], targets: [.target(name: "PickaPicCore", path: "PickaPic/PickaPic/Core"), .testTarget(name: "PickaPicCoreTests", dependencies: ["PickaPicCore"], path: "PickaPic/CoreTests")])
