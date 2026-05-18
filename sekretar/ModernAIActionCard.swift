import SwiftUI

// MARK: - Modern iOS-friendly AI Action Card
/// Современная минималистичная карточка для создания задач/событий в стиле iOS
struct ModernAIActionCard: View {
    @Binding var action: AIAction
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()
    @State private var priority: Int = 1
    @State private var showDatePicker = false
    @State private var isAllDay = false

    init(action: Binding<AIAction>, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._action = action
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        // Initialize from payload
        let payload = action.wrappedValue.payload
        _title = State(initialValue: (payload["title"] as? String) ?? "")
        _notes = State(initialValue: (payload["notes"] as? String) ?? "")
        _selectedDate = State(initialValue: (payload["start"] as? Date) ?? Date())
        _priority = State(initialValue: (payload["priority"] as? Int) ?? 1)
        _isAllDay = State(initialValue: (payload["is_all_day"] as? Bool) ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Title input
                    titleSection

                    // Date/Time picker (for events and scheduled tasks)
                    if supportsDateTime {
                        dateSection
                    }

                    // Priority selector (for tasks)
                    if supportsPriority {
                        prioritySection
                    }

                    // Notes (optional)
                    notesSection
                }
                .padding(20)
            }

            Divider()

            // Action buttons
            actionButtons
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                LinearGradient(
                    colors: [actionColor.opacity(0.8), actionColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Image(systemName: action.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(actionTypeTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(actionSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Confidence badge
            if action.confidence > 0 {
                confidenceBadge
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
            Text("\(Int(action.confidence * 100))%")
                .font(.caption2.weight(.semibold))
        }
        .foregroundColor(actionColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(actionColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Title")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Enter title...", text: $title)
                .font(.body)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(isEvent ? "When" : "Due date")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDatePicker.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(actionColor)

                    Text(formattedDate)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if showDatePicker {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                if isEvent {
                    Toggle("All-day event", isOn: $isAllDay)
                        .font(.subheadline)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Priority Section

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Priority")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(0...3, id: \.self) { p in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            priority = p
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 18))
                                .foregroundColor(priority == p ? .white : priorityColor(p))

                            Text(priorityLabel(p))
                                .font(.caption2.weight(.medium))
                                .foregroundColor(priority == p ? .white : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            priority == p
                                ? priorityColor(p)
                                : Color(uiColor: .secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Notes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add notes (optional)...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }

                TextEditor(text: $notes)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(role: .cancel) {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .foregroundColor(.primary)

            Button {
                updateAction()
                onConfirm()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                    Text(confirmButtonLabel)
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [actionColor.opacity(0.9), actionColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .foregroundColor(.white)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private var actionColor: Color {
        switch action.type {
        case .createTask, .updateTask:
            return .blue
        case .createEvent, .updateEvent:
            return .green
        case .deleteTask, .deleteEvent:
            return .red
        case .suggestTimeSlots:
            return .purple
        case .prioritizeTasks:
            return .orange
        default:
            return .gray
        }
    }

    private var actionTypeTitle: String {
        switch action.type {
        case .createTask: return "New Task"
        case .createEvent: return "New Event"
        case .updateTask: return "Update Task"
        case .updateEvent: return "Update Event"
        case .deleteTask: return "Delete Task"
        case .deleteEvent: return "Delete Event"
        case .suggestTimeSlots: return "Schedule Task"
        case .prioritizeTasks: return "Prioritize"
        default: return action.type.displayName
        }
    }

    private var actionSubtitle: String {
        switch action.type {
        case .createTask: return "Create a new task"
        case .createEvent: return "Add to calendar"
        case .updateTask, .updateEvent: return "Edit details"
        case .suggestTimeSlots: return "Find best time"
        default: return "AI suggestion"
        }
    }

    private var confirmButtonLabel: String {
        switch action.type {
        case .createTask, .createEvent: return "Create"
        case .updateTask, .updateEvent: return "Update"
        case .deleteTask, .deleteEvent: return "Delete"
        default: return "Confirm"
        }
    }

    private var supportsDateTime: Bool {
        [.createEvent, .updateEvent, .createTask, .suggestTimeSlots].contains(action.type)
    }

    private var supportsPriority: Bool {
        [.createTask, .updateTask, .prioritizeTasks].contains(action.type)
    }

    private var isEvent: Bool {
        [.createEvent, .updateEvent].contains(action.type)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }
        return formatter.string(from: selectedDate)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 0: return "Low"
        case 1: return "Normal"
        case 2: return "High"
        case 3: return "Urgent"
        default: return ""
        }
    }

    private func priorityColor(_ p: Int) -> Color {
        switch p {
        case 0: return .gray
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        default: return .gray
        }
    }

    private func updateAction() {
        action.payload["title"] = title
        action.payload["notes"] = notes.isEmpty ? nil : notes
        action.payload["priority"] = priority

        if supportsDateTime {
            action.payload["start"] = selectedDate
            if isEvent {
                action.payload["is_all_day"] = isAllDay
                let duration: TimeInterval = isAllDay ? 86400 : 3600
                action.payload["end"] = selectedDate.addingTimeInterval(duration)
            }
        }
    }
}

#Preview {
    let sampleAction = AIAction(
        type: .createTask,
        title: "Create new task",
        description: "Create a task with AI assistance",
        confidence: 0.92,
        requiresConfirmation: true,
        payload: [
            "title": "Buy groceries",
            "priority": 2,
            "notes": "Milk, bread, eggs"
        ]
    )

    return ModernAIActionCard(
        action: .constant(sampleAction),
        onConfirm: {},
        onCancel: {}
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}