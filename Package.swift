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
    targets: [
        .target(
            name: "sekretar",
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
