import SwiftUI

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
                        Color(UIColor.systemBackground)
                            .ignoresSafeArea()
                    }
                    .navigationViewStyle(.stack)
                    .tag(0)

                    // Вкладка "Календарь"
                    NavigationView {
                        CalendarScreen(viewModel: CalendarViewModel(context: context))
                    }
                    .navigationViewStyle(.stack)
                    .tag(1)

                    // Вкладка "Задачи"
                    NavigationView {
                        TaskListView(viewModel: TaskListViewModel(repo: TaskRepositoryCD(context: context)))
                    }
                    .navigationViewStyle(.stack)
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // свайп между разделами

                // Custom bottom toolbar to switch tabs
                CustomTabBar(selected: $selectedTab)
            }

            // Floating Chat Button: только на Главной (selectedTab == 0)
            if selectedTab == 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showChat = true }) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(
                                    Circle()
                                        .fill(DesignSystem.Colors.primaryBlue)
                                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                                )
                        }
                        .accessibilityLabel("Открыть чат с ИИ")
                        .padding(.trailing, 20)
                        .padding(.bottom, 84) // над таббаром на компактных iPhone
                    }
                }
                .allowsHitTesting(true)
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

private struct CustomTabBar: View {
    @Binding var selected: Int

    private struct Item: Identifiable { let id: Int; let icon: String; let title: String }
    private let items: [Item] = [
        .init(id: 0, icon: "house.fill", title: "Главная"),
        .init(id: 1, icon: "calendar", title: "Календарь"),
        .init(id: 2, icon: "checklist", title: "Задачи")
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
