import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DemoCalendarAI: App {
    let persistence = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            DemoContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

struct DemoContentView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var selectedTab = 0
    @State private var showChat = false
    @State private var pendingFocusDate: Date? = nil
    @State private var previousTab = 0

    var body: some View {
        ZStack { // Overlay кнопку чата поверх TabBar, чтобы она не пряталась на маленьких экранах
            VStack(spacing: 0) {
                // Swipeable pages
                TabView(selection: $selectedTab) {
                    // Вкладка "Главная"
                    NavigationView {
                        HomeDashboardView(
                            openChat: { showChat = true },
                            openCalendar: { selectedTab = 1 },
                            openTasks: { selectedTab = 2 },
                            openSettings: { selectedTab = 3 }
                        )
                    }
#if os(iOS)
                    .navigationViewStyle(.stack)
#endif
                    .tag(0)

                    // Вкладка "Календарь"
                    NavigationView {
                        CalendarScreen(viewModel: CalendarViewModel(context: context))
                    }
#if os(iOS)
                    .navigationViewStyle(.stack)
#endif
                    .tag(1)

                    // Вкладка "Задачи"
                    NavigationView {
                        TaskListView(viewModel: TaskListViewModel(repo: TaskRepositoryCD(context: context)))
                    }
#if os(iOS)
                    .navigationViewStyle(.stack)
#endif
                    .tag(2)

                    // Вкладка "Настройки"
                    NavigationView {
                        SettingsView(context: context)
                    }
#if os(iOS)
                    .navigationViewStyle(.stack)
#endif
                    .tag(3)
                }
#if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never)) // свайп между разделами
#endif

                // Custom bottom toolbar to switch tabs
                CustomTabBar(selected: $selectedTab)
            }

        }
        .sheet(isPresented: $showChat) {
            NavigationView { ChatScreen() }
        }
        .onChange(of: selectedTab) { newValue in
            if previousTab == 2 && newValue != 2 {
                NotificationCenter.default.post(name: .dismissKeyboard, object: nil)
            }
            previousTab = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCalendarOn)) { note in
            if let d = note.userInfo?["date"] as? Date { pendingFocusDate = d }
            selectedTab = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let d = pendingFocusDate {
                    NotificationCenter.default.post(name: .focusCalendarDate, object: nil, userInfo: ["date": d])
                    pendingFocusDate = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTasksOn)) { _ in
            selectedTab = 2
        }
    }
}

private struct HomeDashboardView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true)],
        animation: .default
    ) private var tasks: FetchedResults<TaskEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)],
        animation: .default
    ) private var events: FetchedResults<EventEntity>

    let openChat: () -> Void
    let openCalendar: () -> Void
    let openTasks: () -> Void
    let openSettings: () -> Void

    private var openTasksCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    private var todayEventsCount: Int {
        let calendar = Calendar.current
        return events.filter { event in
            guard let start = event.startDate else { return false }
            return calendar.isDateInToday(start)
        }.count
    }

    private var nextTask: TaskEntity? {
        tasks.first { !$0.isCompleted }
    }

    private var nextEvent: EventEntity? {
        let now = Date()
        return events.first { ($0.startDate ?? .distantPast) >= now }
    }

    private var todayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date()).capitalized
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                todaySummary
                primaryActions
                nextUpSection
                appShortcuts
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 96)
        }
        .background(AppBackground().ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(todayLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Sekretar")
                    .font(.largeTitle.weight(.bold))
            }

            Spacer()

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.Colors.cardBackground, in: Circle())
            }
            .accessibilityLabel("Настройки")
        }
    }

    private var todaySummary: some View {
        VStack(spacing: 0) {
            HomeMetricLine(
                icon: "calendar",
                tint: .blue,
                title: "Сегодня",
                value: "\(todayEventsCount) \(plural(todayEventsCount, one: "событие", few: "события", many: "событий"))"
            )
            Divider().padding(.leading, 46)
            HomeMetricLine(
                icon: "checkmark.circle",
                tint: .green,
                title: "Открытые задачи",
                value: "\(openTasksCount)"
            )
        }
        .background(DesignSystem.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var primaryActions: some View {
        VStack(spacing: 0) {
            HomeNavigationRow(
                icon: "sparkles",
                tint: .blue,
                title: "Спросить AI",
                subtitle: "Вопросы или команды для задач",
                action: openChat
            )
            Divider().padding(.leading, 46)
            HStack(spacing: 0) {
                HomeCompactAction(title: "Календарь", icon: "calendar", tint: .orange, action: openCalendar)
                Divider().frame(height: 44)
                HomeCompactAction(title: "Задачи", icon: "checklist", tint: .green, action: openTasks)
            }
            .frame(height: 64)
        }
        .background(DesignSystem.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var nextUpSection: some View {
        HomeSection(title: "Ближайшее") {
            VStack(spacing: 0) {
                if let event = nextEvent {
                    HomeNavigationRow(
                        icon: "calendar.badge.clock",
                        tint: .orange,
                        title: event.title ?? "Событие",
                        subtitle: format(event.startDate),
                        action: openCalendar
                    )
                }
                if nextEvent != nil && nextTask != nil {
                    Divider().padding(.leading, 46)
                }
                if let task = nextTask {
                    HomeNavigationRow(
                        icon: "checkmark.circle",
                        tint: .green,
                        title: task.title ?? "Задача",
                        subtitle: format(task.dueDate),
                        action: openTasks
                    )
                }
                if nextEvent == nil && nextTask == nil {
                    HomeEmptyState()
                }
            }
            .background(DesignSystem.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var appShortcuts: some View {
        HomeSection(title: "Возможности") {
            VStack(spacing: 0) {
                HomeInfoRow(icon: "message", tint: .blue, title: "Чат", subtitle: "AI-вопросы и команды в одном месте")
                Divider().padding(.leading, 46)
                HomeInfoRow(icon: "bell", tint: .red, title: "Напоминания", subtitle: "Уведомления для задач и событий")
                Divider().padding(.leading, 46)
                HomeInfoRow(icon: "arrow.triangle.2.circlepath", tint: .purple, title: "Синхронизация", subtitle: "Базовая офлайн-очередь уже в приложении")
            }
            .background(DesignSystem.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return "Дата не задана" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }
}

private struct AppBackground: View {
    var body: some View {
#if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
#elseif canImport(AppKit)
        Color(NSColor.windowBackgroundColor)
#else
        Color.white
#endif
    }
}

private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            content
        }
    }
}

private struct HomeMetricLine: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            HomeSymbol(icon: icon, tint: tint)
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}

private struct HomeNavigationRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HomeSymbol(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeCompactAction: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeInfoRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            HomeSymbol(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
    }
}

private struct HomeEmptyState: View {
    var body: some View {
        HStack(spacing: 12) {
            HomeSymbol(icon: "tray", tint: .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text("План свободен")
                    .font(.body)
                Text("Создайте задачу или событие через чат")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
    }
}

private struct HomeSymbol: View {
    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct CustomTabBar: View {
    @Binding var selected: Int

    private struct Item: Identifiable { let id: Int; let icon: String; let title: String }
    private let items: [Item] = [
        .init(id: 0, icon: "house.fill", title: "Главная"),
        .init(id: 1, icon: "calendar", title: "Календарь"),
        .init(id: 2, icon: "checklist", title: "Задачи"),
        .init(id: 3, icon: "gearshape.fill", title: "Настройки")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                ForEach(items) { item in
                    Button(action: { selected = item.id }) {
                        VStack(spacing: 2) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selected == item.id ? DesignSystem.Colors.primaryBlue : .secondary)
                            Text(item.title)
                                .font(.caption2)
                                .foregroundColor(selected == item.id ? DesignSystem.Colors.primaryBlue : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 8)
            .background(Material.ultraThin)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}


#Preview {
    DemoContentView()
}
