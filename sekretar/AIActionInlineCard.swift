import SwiftUI

struct AIActionInlineCard: View {
    @Binding var action: AIAction
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onOpenTaskEditor: ((AIAction) -> Void)?
    let onOpenEventEditor: ((AIAction) -> Void)?

    @State private var editedTitle: String
    @State private var editedNotes: String
    @State private var editedStart: Date?
    @State private var editedEnd: Date?
    @State private var editedIsAllDay: Bool
    @State private var editedPriority: Int?
    @State private var showingDatePicker = false
    @State private var showingEndDatePicker = false

    init(
        action: Binding<AIAction>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onOpenTaskEditor: ((AIAction) -> Void)? = nil,
        onOpenEventEditor: ((AIAction) -> Void)? = nil
    ) {
        self._action = action
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onOpenTaskEditor = onOpenTaskEditor
        self.onOpenEventEditor = onOpenEventEditor

        let payload = action.wrappedValue.payload
        _editedTitle = State(initialValue: (payload["title"] as? String) ?? action.wrappedValue.title)
        _editedNotes = State(initialValue: payload["notes"] as? String ?? "")
        _editedStart = State(initialValue: payload["start"] as? Date)
        _editedEnd = State(initialValue: payload["end"] as? Date)
        _editedIsAllDay = State(initialValue: payload["is_all_day"] as? Bool ?? false)
        if let number = payload["priority"] as? NSNumber {
            _editedPriority = State(initialValue: number.intValue)
        } else if let intVal = payload["priority"] as? Int {
            _editedPriority = State(initialValue: intVal)
        } else {
            _editedPriority = State(initialValue: nil)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [actionColor.opacity(0.15), actionColor.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                HStack {
                    ZStack {
                        Circle()
                            .fill(actionColor.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: action.type.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(actionColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionTypeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(editedTitle.isEmpty ? "Новое событие" : editedTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 60)

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Label("Название", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Введите название...", text: $editedTitle)
                        .font(.system(size: 16))
                        .textFieldStyle(.roundedBorder)
                }

                // Date/Time picker (tappable)
                if action.type == .createEvent || action.type == .createTask {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Время", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(action: { showingDatePicker.toggle() }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundStyle(actionColor)

                                if let start = editedStart {
                                    Text(formatDate(start))
                                        .font(.system(size: 15))
                                } else {
                                    Text("Выбрать время")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        if showingDatePicker {
                            DatePicker(
                                "Начало",
                                selection: Binding(
                                    get: { editedStart ?? Date() },
                                    set: { editedStart = $0 }
                                ),
                                displayedComponents: editedIsAllDay ? [.date] : [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()

                            if action.type == .createEvent && !editedIsAllDay {
                                DatePicker(
                                    "Окончание",
                                    selection: Binding(
                                        get: { editedEnd ?? Date().addingTimeInterval(3600) },
                                        set: { editedEnd = $0 }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }

                            Toggle("Весь день", isOn: $editedIsAllDay)
                                .font(.system(size: 15))
                                .tint(actionColor)
                        }
                    }
                }

                // Compact priority selector for tasks (always visible)
                if action.type == .createTask || action.type == .updateTask {
                    HStack(spacing: 12) {
                        Label("Приоритет", systemImage: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Compact segmented priority selector with proper spacing
                        HStack(spacing: 12) {
                            ForEach([
                                (1, Color.blue),
                                (2, Color.orange),
                                (3, Color.red)
                            ], id: \.0) { priority, color in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if editedPriority == priority {
                                            editedPriority = nil // Deselect if same
                                        } else {
                                            editedPriority = priority
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(editedPriority == priority ? color : color.opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(editedPriority == priority ? .white : color)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(color.opacity(0.3), lineWidth: editedPriority == priority ? 0 : 1)
                                    )
                                    .scaleEffect(editedPriority == priority ? 1.1 : 1.0)
                                    .shadow(color: editedPriority == priority ? color.opacity(0.4) : .clear, radius: 5)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        // Priority text label
                        if let priority = editedPriority {
                            Text(priority == 3 ? "Высокий" : priority == 2 ? "Средний" : "Низкий")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(priority == 3 ? .red : priority == 2 ? .orange : .blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill((priority == 3 ? Color.red : priority == 2 ? Color.orange : Color.blue).opacity(0.1))
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                // Notes
                if !editedNotes.isEmpty || action.type == .createTask || action.type == .createEvent {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Заметки", systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Добавить заметку...", text: $editedNotes, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(16)

            Divider()

            // Action buttons with animation
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onCancel()
                    }
                }) {
                    HStack {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Отмена")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.05))

                Divider()
                    .frame(width: 0.5)
                    .frame(maxHeight: 48)

                Button(action: {
                    syncPayload()
                    withAnimation(.easeOut(duration: 0.2)) {
                        onConfirm()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Сохранить")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(actionColor)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 48)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .onAppear { seedFromAction() }
        .animation(.easeInOut(duration: 0.3), value: showingDatePicker)
        .animation(.easeInOut(duration: 0.2), value: editedPriority)
    }

    // MARK: - Helpers

    private var actionTypeLabel: String {
        switch action.type {
        case .createTask: return "НОВАЯ ЗАДАЧА"
        case .updateTask: return "ИЗМЕНИТЬ ЗАДАЧУ"
        case .createEvent: return "НОВОЕ СОБЫТИЕ"
        case .updateEvent: return "ИЗМЕНИТЬ СОБЫТИЕ"
        case .deleteTask: return "УДАЛИТЬ ЗАДАЧУ"
        case .deleteEvent: return "УДАЛИТЬ СОБЫТИЕ"
        default: return "ДЕЙСТВИЕ"
        }
    }

    private var actionColor: Color {
        switch action.type {
        case .createTask, .updateTask:
            return .blue
        case .createEvent, .updateEvent:
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Nice green
        case .deleteTask, .deleteEvent:
            return .red
        default:
            return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = editedIsAllDay ? "'Сегодня'" : "'Сегодня,' HH:mm"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = editedIsAllDay ? "'Завтра'" : "'Завтра,' HH:mm"
        } else {
            formatter.dateFormat = editedIsAllDay ? "d MMMM" : "d MMMM, HH:mm"
        }

        return formatter.string(from: date)
    }

    private func seedFromAction() {
        let payload = action.payload
        editedTitle = (payload["title"] as? String) ?? action.title
        editedNotes = payload["notes"] as? String ?? ""
        editedStart = payload["start"] as? Date
        editedEnd = payload["end"] as? Date
        editedIsAllDay = payload["is_all_day"] as? Bool ?? false

        if let number = payload["priority"] as? NSNumber {
            editedPriority = number.intValue
        } else if let intVal = payload["priority"] as? Int {
            editedPriority = intVal
        }
    }

    private func syncPayload() {
        var newPayload = action.payload
        newPayload["title"] = editedTitle
        newPayload["notes"] = editedNotes

        if let start = editedStart {
            newPayload["start"] = start
        }
        if let end = editedEnd {
            newPayload["end"] = end
        }

        newPayload["is_all_day"] = editedIsAllDay

        if let priority = editedPriority {
            newPayload["priority"] = priority
        }

        action.payload = newPayload
    }
}