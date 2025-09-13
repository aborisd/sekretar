  // swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sekretar",
    defaultLocalization: "en", // или "ru"
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "sekretar", targets: ["sekretar"])
    ],
    targets: [
        .target(
            name: "sekretar",
            // исходники лежат в папке "sekretar" (переименовано)
            path: "sekretar",
            // на всякий случай исключим файлы, которые точно не должны компилироваться
            exclude: [
                // исключаем ресурсы из исходников, они подключаются отдельно ниже
                "en.lproj",
                "ru.lproj",
                "Assets.xcassets",
                // исключаем файлы, которые не являются исходниками Swift
                "Info.plist",
                "calendAIApp.swift.backup",
                "EnhancedCalendarView.swift.backup",
                "SettingsViewModel.swift.backup",
                // модель CoreData не входит в пакет
                "calendAI.xcdatamodeld"
            ],
            // берём все Swift-файлы внутри path
            // ресурсы: локализации в корне + ассеты внутри папки модуля
            resources: [
                .process("en.lproj"),
                .process("ru.lproj"),
                .process("Assets.xcassets")
            ]
        )
    ]
)
