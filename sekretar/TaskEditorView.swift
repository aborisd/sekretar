import SwiftUI
import CoreData

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date?
    @State private var hasDue: Bool
    @State private var priority: Int
    @State private var selectedProject: ProjectEntity?
    @State private var showingDeleteAlert = false
    @State private var isNewTask: Bool
    @State private var isSaving = false
    
    @FetchRequest(
        entity: ProjectEntity.entity(),
        sortDescriptors: [NSSortDescriptor(key: "title", ascending: true)]
    ) private var projects: FetchedResults<ProjectEntity>
    
    let task: TaskEntity

    init(task: TaskEntity) {
        self.task = task
        _title = State(initialValue: task.title ?? "")
        _notes = State(initialValue: task.notes ?? "")
        _dueDate = State(initialValue: task.dueDate)
        _hasDue = State(initialValue: task.dueDate != nil)
        _priority = State(initialValue: Int(task.priority))
        _selectedProject = State(initialValue: task.project)
        _isNewTask = State(initialValue: task.title?.isEmpty ?? true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        headerSection
                        
                        // Title Section
                        titleSection
                        
                        // Notes Section
                        notesSection
                        
                        // Due Date Section
                        dueDateSection
                        
                        // Priority Section
                        prioritySection
                        
                        // Project Section
                        projectSection
                        
                        // Action Buttons
                        actionsSection
                        
                        // Delete Button (if editing)
                        if !isNewTask {
                            deleteSection
                        }
                        
                        Color.clear.frame(height: DesignSystem.Spacing.xl)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        cancelEditing()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button(L10n.Common.done) {
                            save()
                        }
                        .foregroundColor(canSave ? DesignSystem.Colors.primaryBlue : DesignSystem.Colors.textTertiary)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                    }
                }
            }
            .alert(L10n.Tasks.deleteConfirmation, isPresented: $showingDeleteAlert) {
                Button(L10n.Common.cancel, role: .cancel) { }
                Button(L10n.Common.delete, role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text(L10n.Tasks.deleteMessage)
            }
            .onDisappear { cleanupIfNewAndEmpty() }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: isNewTask ? "plus.circle.fill" : "pencil.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primaryBlue)
                .symbolEffect(.pulse, isActive: isNewTask)
            
            Text(isNewTask ? L10n.Tasks.newTask : L10n.Tasks.editTask)
                .font(DesignSystem.Typography.title1)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if !isNewTask {
                Text("Modified: \(task.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(L10n.Tasks.taskTitle, systemImage: "text.cursor")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            TextField(L10n.Tasks.taskTitlePlaceholder, text: $title)
                .font(DesignSystem.Typography.body)
                .textFieldStyle(.plain)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(
                    color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y
                )
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(L10n.Tasks.notes, systemImage: "note.text")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            TextField(L10n.Tasks.notesPlaceholder, text: $notes, axis: .vertical)
                .font(DesignSystem.Typography.body)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(
                    color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y
                )
        }
    }
    
    // MARK: - Due Date Section
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Label(L10n.Tasks.dueDate, systemImage: "calendar.badge.clock")
                    .font(DesignSystem.Typography.cardTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $hasDue.animation(DesignSystem.Animation.standard))
                    .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.primaryBlue))
            }
            
            if hasDue {
                DatePicker(
                    L10n.Tasks.selectDateTime,
                    selection: Binding<Date>(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(
                    color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Priority Section
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label(L10n.Tasks.priority, systemImage: "exclamationmark.triangle.fill")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(0...3, id: \.self) { level in
                    PriorityButton(
                        level: level,
                        isSelected: priority == level,
                        action: {
                            withAnimation(DesignSystem.Animation.bouncy) {
                                priority = level
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    )
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Project Section
    private var projectSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Проект", systemImage: "folder.fill")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // None option
                    ProjectSelectionButton(
                        title: "Нет проекта",
                        color: Color.gray,
                        isSelected: selectedProject == nil
                    ) {
                        withAnimation(DesignSystem.Animation.bouncy) {
                            selectedProject = nil
                        }
                    }
                    
                    // Available projects
                    ForEach(projects, id: \.id) { project in
                        ProjectSelectionButton(
                            title: project.title ?? "Project",
                            color: Color(hex: project.color ?? "#3B82F6"),
                            isSelected: selectedProject?.id == project.id
                        ) {
                            withAnimation(DesignSystem.Animation.bouncy) {
                                selectedProject = project
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xs)
            }
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button {
                save()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text(isNewTask ? L10n.Tasks.createTask : L10n.Tasks.saveChanges)
                        .font(DesignSystem.Typography.buttonText)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
            }
            .primaryButton()
            .disabled(!canSave || isSaving)
            
            if hasDue && dueDate != nil {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(DesignSystem.Colors.primaryTeal)
                    Text(L10n.Tasks.reminderWillBeCreated)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.primaryTeal.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
        }
    }
    
    // MARK: - Delete Section
    private var deleteSection: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.title2)
                Text(L10n.Tasks.deleteTask)
                    .font(DesignSystem.Typography.buttonText)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .foregroundColor(.white)
            .background(DesignSystem.Colors.overdue)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
    
    // MARK: - Helpers
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func save() {
        guard canSave else { return }
        
        withAnimation(DesignSystem.Animation.standard) {
            isSaving = true
        }
        
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = Int16(priority)
        task.dueDate = hasDue ? dueDate : nil
        task.project = selectedProject
        task.updatedAt = Date()
        
        do {
            try context.save()
            
            Task {
                if hasDue, let dueDate = dueDate {
                    await NotificationService.scheduleTaskReminder(task)
                } else {
                    if let taskId = task.id {
                        NotificationService.cancelReminder(for: taskId)
                    }
                }
            }
            
            AnalyticsService.shared.track(isNewTask ? .taskCreated : .taskUpdated, properties: [
                "priority": priority,
                "has_due_date": hasDue,
                "has_notes": !(task.notes?.isEmpty ?? true)
            ])
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        isSaving = false
    }
    
    private func deleteTask() {
        withAnimation(DesignSystem.Animation.standard) {
            if let taskId = task.id {
                NotificationService.cancelReminder(for: taskId)
            }
            context.delete(task)
            try? context.save()
            
            AnalyticsService.shared.track(.taskDeleted, properties: [
                "priority": Int(task.priority),
                "was_completed": task.isCompleted
            ])
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private func cancelEditing() {
        cleanupIfNewAndEmpty()
        dismiss()
    }

    private func cleanupIfNewAndEmpty() {
        // Удаляем временную пустую задачу, если пользователь вышел без сохранения
        if isNewTask && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(task)
            try? context.save()
        }
    }
}

// MARK: - Priority Button Component
struct PriorityButton: View {
    let level: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: level == 0 ? "minus" : "\(level).circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : priorityColor)
                
                Text(level == 0 ? L10n.Priority.none : "P\(level)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(isSelected ? priorityColor : DesignSystem.Colors.cardBackground)
                    .shadow(
                        color: isSelected ? priorityColor.opacity(0.3) : DesignSystem.Shadow.small.color,
                        radius: isSelected ? 8 : DesignSystem.Shadow.small.radius,
                        x: DesignSystem.Shadow.small.x,
                        y: DesignSystem.Shadow.small.y
                    )
            )
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(DesignSystem.Animation.bouncy, value: isSelected)
    }
    
    private var priorityColor: Color {
        switch level {
        case 3: return DesignSystem.Colors.priorityHigh
        case 2: return DesignSystem.Colors.priorityMedium
        case 1: return DesignSystem.Colors.priorityLow
        default: return DesignSystem.Colors.priorityNone
        }
    }
}

// MARK: - Project Selection Button
struct ProjectSelectionButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color : DesignSystem.Colors.cardBackground)
                    .shadow(
                        color: isSelected ? color.opacity(0.3) : DesignSystem.Shadow.small.color,
                        radius: isSelected ? 4 : DesignSystem.Shadow.small.radius,
                        x: DesignSystem.Shadow.small.x,
                        y: DesignSystem.Shadow.small.y
                    )
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(DesignSystem.Animation.bouncy, value: isSelected)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
