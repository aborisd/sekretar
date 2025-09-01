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
        TabView(selection: $selectedTab) {
            // Вкладка "Сегодня" (чистый экран без демо-текста) + плавающая кнопка чата
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
            .tabItem {
                Image(systemName: "house.fill")
                Text("Главная")
            }
            .tag(0)

            // Вкладка "Календарь"
            CalendarView()
            .tabItem {
                Image(systemName: "calendar")
                Text("Календарь")  
            }
            .tag(1)
            
            // Вкладка "Задачи"
            TaskListView(viewModel: TaskListViewModel(repo: TaskRepositoryCD(context: context)))
            .tabItem {
                Image(systemName: "checklist")
                Text("Задачи")
            }
            .tag(2)
        }
        .sheet(isPresented: $showChat) {
            NavigationView { ChatScreen() }
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
