// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AnimeWallpaper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/rive-app/rive-ios", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AnimeWallpaper",
            dependencies: [.product(name: "RiveRuntime", package: "rive-ios")],
            resources: [.copy("Resources/anime-girl.riv")]
        )
    ]
)
