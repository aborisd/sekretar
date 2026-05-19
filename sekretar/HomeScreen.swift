import SwiftUI
import CoreData

struct HomeScreen: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == NO"),
        animation: .default
    )
    private var incompleteTasks: FetchedResults<TaskEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)],
        animation: .default
    )
    private var upcomingEvents: FetchedResults<EventEntity>

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Приветствие с учетом времени суток
                    greetingSection

                    // Сегодняшние задачи
                    todaySection

                    // Quick Actions
                    quickActionsSection

                    // Статистика (опционально)
                    statsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Главная")
        }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greetingText)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(motivationalText)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро! 🌅"
        case 12..<17: return "Добрый день! ☀️"
        case 17..<22: return "Добрый вечер! 🌆"
        default: return "Доброй ночи! 🌙"
        }
    }

    private var motivationalText: String {
        let taskCount = incompleteTasks.count
        if taskCount == 0 {
            return "Все задачи выполнены! Отличная работа"
        } else if taskCount <= 3 {
            return "У вас \(taskCount) задачи на сегодня"
        } else {
            return "У вас \(taskCount) задач — разберём их вместе"
        }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сегодня")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if todayTasks.isEmpty && todayEvents.isEmpty {
                emptyTodayCard
            } else {
                VStack(spacing: 8) {
                    ForEach(todayEvents.prefix(3)) { event in
                        TodayEventRow(event: event)
                    }
                    ForEach(todayTasks.prefix(3)) { task in
                        TodayTaskRow(task: task)
                    }
                }
            }
        }
    }

    private var todayTasks: [TaskEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return incompleteTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= today && dueDate < tomorrow
        }
    }

    private var todayEvents: [EventEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return upcomingEvents.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate >= today && startDate < tomorrow
        }
    }

    private var emptyTodayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Пока ничего не запланировано")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Создайте первую задачу или событие")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые действия")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Новая задача",
                    color: .blue
                ) {
                    // TODO: Открыть редактор задачи
                }

                QuickActionCard(
                    icon: "calendar.badge.plus",
                    title: "Событие",
                    color: .orange
                ) {
                    // TODO: Открыть редактор события
                }

                QuickActionCard(
                    icon: "bubble.left.fill",
                    title: "Открыть чат",
                    color: .green
                ) {
                    // TODO: Переключиться на вкладку чата
                }

                QuickActionCard(
                    icon: "mic.fill",
                    title: "Голосовой ввод",
                    color: .purple
                ) {
                    // TODO: Открыть голосовой ввод
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("На этой неделе")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: 12) {
                StatCard(
                    value: "\(completedThisWeek)",
                    label: "Выполнено",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    value: "\(incompleteTasks.count)",
                    label: "Осталось",
                    icon: "circle",
                    color: .blue
                )
            }
        }
    }

    private var completedThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "isCompleted == YES AND updatedAt >= %@",
            weekAgo as NSDate
        )

        return (try? context.count(for: request)) ?? 0
    }
}

// MARK: - Today Row Components

struct TodayEventRow: View {
    let event: EventEntity

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Событие")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let startDate = event.startDate {
                    Text(formatTime(startDate))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

struct TodayTaskRow: View {
    let task: TaskEntity

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)

            Text(task.title ?? "Задача")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color.gradient)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Preview

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
            .environment(\.managedObjectContext, PersistenceController.preview().container.viewContext)
    }
}
