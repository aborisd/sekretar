import SwiftUI
import CoreData

struct TaskRowView: View {
    @ObservedObject var task: TaskEntity
    @Environment(\.managedObjectContext) private var ctx
    @State private var isPressed = false
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Красивый чекбокс с анимацией
            Button {
                withAnimation(DesignSystem.Animation.bouncy) {
                    task.isCompleted.toggle()
                    task.updatedAt = Date()
                    try? ctx.save()
                }
                
                Task {
                    if task.isCompleted {
                        if let taskId = task.id {
                            NotificationService.cancelReminder(for: taskId)
                        }
                    } else {
                        await NotificationService.scheduleTaskReminder(task)
                    }
                }
                
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
            } label: {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? DesignSystem.Colors.completed : DesignSystem.Colors.textTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(DesignSystem.Colors.completed)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .scaleEffect(task.isCompleted ? 1.0 : 0.5)
                            .animation(DesignSystem.Animation.bouncy, value: task.isCompleted)
                    }
                }
            }
            
            // Статус индикатор
            StatusIndicator(
                isCompleted: task.isCompleted,
                isOverdue: isTaskOverdue
            )
            
            // Основной контент
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title ?? "")
                    .font(DesignSystem.Typography.cardTitle)
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    .strikethrough(task.isCompleted)
                    .animation(DesignSystem.Animation.standard, value: task.isCompleted)
                
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                }
                
                if let due = task.dueDate {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(isTaskOverdue ? DesignSystem.Colors.overdue : DesignSystem.Colors.textSecondary)
                        
                        Text(due.formatted(date: .abbreviated, time: .shortened))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(isTaskOverdue ? DesignSystem.Colors.overdue : DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Приоритет и действия
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                PriorityBadge(priority: task.priority)
                
                Button {
                    showingDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.primaryBlue)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .enhancedCard(isPressed: isPressed)
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignSystem.Animation.quick) {
                    isPressed = false
                }
                showingDetails = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Удаление
            Button(role: .destructive) {
                withAnimation(DesignSystem.Animation.standard) {
                    if let taskId = task.id {
                        NotificationService.cancelReminder(for: taskId)
                    }
                    ctx.delete(task)
                    try? ctx.save()
                }
            } label: {
                Label(L10n.Common.delete, systemImage: "trash.fill")
            }
            
            // Переключение статуса
            Button {
                withAnimation(DesignSystem.Animation.bouncy) {
                    task.isCompleted.toggle()
                    try? ctx.save()
                    Task {
                        if task.isCompleted {
                            if let taskId = task.id {
                            NotificationService.cancelReminder(for: taskId)
                        }
                        } else {
                            await NotificationService.scheduleTaskReminder(task)
                        }
                    }
                }
            } label: {
                Label(
                    task.isCompleted ? L10n.Tasks.resume : L10n.Tasks.complete,
                    systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(DesignSystem.Colors.completed)
        }
        .sheet(isPresented: $showingDetails) {
            TaskEditorView(task: task)
        }
    }
    
    private var isTaskOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return !task.isCompleted && dueDate < Date()
    }
}
