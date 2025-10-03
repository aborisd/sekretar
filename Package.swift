  // swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sekretar",
    defaultLocalization: "en", // или "ru"
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "sekretar", targets: ["sekretar"])
    ],
    dependencies: [
        // SQLite.swift для Vector Memory Store
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "sekretar",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "sekretar",
            exclude: [
                "en.lproj",
                "ru.lproj",
                "Assets.xcassets",
                "Info.plist",
                "calendAIApp.swift",
                "calendAIApp.swift.backup",
                "EnhancedCalendarView.swift.backup",
                "SettingsViewModel.swift.backup",
                "calendAI.xcdatamodeld"
            ],
            resources: [
                .process("en.lproj"),
                .process("ru.lproj"),
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "sekretarTests",
            dependencies: ["sekretar"],
            path: "sekretarTests"
        )
    ]
)
