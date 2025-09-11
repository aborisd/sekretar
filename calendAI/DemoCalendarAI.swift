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

    var body: some View {
        VStack(spacing: 0) {
            // Swipeable pages
            TabView(selection: $selectedTab) {
                // Вкладка "Главная" с плавающей кнопкой чата
                NavigationView {
                    ZStack {
                        Color(UIColor.systemBackground)
                            .ignoresSafeArea()

                        // Здесь можно добавить контент главного экрана позже

                        // Floating Chat Button (bottom-right)
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
                                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                                        )
                                }
                                .accessibilityLabel("Открыть чат с ИИ")
                                .padding(.trailing, 20)
                                .padding(.bottom, 28)
                            }
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                }
                .tag(0)

                // Вкладка "Календарь"
                CalendarView()
                    .tag(1)

                // Вкладка "Задачи"
                TaskListView(viewModel: TaskListViewModel(repo: TaskRepositoryCD(context: context)))
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // свайп между разделами

            // Custom bottom toolbar to switch tabs
            CustomTabBar(selected: $selectedTab)
        }
        .sheet(isPresented: $showChat) {
            NavigationView { ChatScreen() }
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
