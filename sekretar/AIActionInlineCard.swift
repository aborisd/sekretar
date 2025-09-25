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
    @State private var isSyncingFromAction = false

    private let defaultDuration: TimeInterval = 3600
    private let handledKeys: Set<String> = ["title", "notes", "start", "end", "is_all_day", "priority"]

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
        VStack(alignment: .leading, spacing: 12) {
            header
            descriptionSection
            editableFields
            if !otherItems.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(otherItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.title)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(item.value)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.caption)
                    }
                }
            }
            actionButtons
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { seedFromAction() }
        .onChange(of: action.id) { _ in seedFromAction() }
        .onChange(of: editedTitle) { _ in syncPayload() }
        .onChange(of: editedNotes) { _ in syncPayload() }
        .onChange(of: editedStart) { _ in syncPayload() }
        .onChange(of: editedEnd) { _ in syncPayload() }
        .onChange(of: editedPriority) { _ in syncPayload() }
        .onChange(of: editedIsAllDay) { _ in adjustForAllDayChange() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: action.type.icon)
                .foregroundStyle(actionColor)
            Text(action.title)
                .font(.headline)
        }
    }

    private var descriptionSection: some View {
        Text(action.description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.AIInline.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(L10n.AIInline.titlePlaceholder, text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
            }

            if supportsScheduleControls {
                scheduleSection
            }

            if let priorityBinding = priorityBinding {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.AIInline.priority)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper(value: priorityBinding, in: 0...3) {
                        Text(priorityLabel(for: priorityBinding.wrappedValue))
                    }
                }
            }

            if showNotesField {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.AIInline.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .topLeading) {
                        if editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(L10n.AIInline.notesPlaceholder)
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                        }
                        TextEditor(text: $editedNotes)
                            .frame(minHeight: 96)
                            .padding(4)
                    }
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.secondary.opacity(0.2)))
                }
            }

            advancedEditorButton
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if editedStart != nil {
                    Button(role: .destructive, action: clearSchedule) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .accessibilityLabel(L10n.AIInline.removeSchedule)
                }
                Toggle(isOn: $editedIsAllDay) {
                    Text(L10n.AIInline.allDay)
                }
                .toggleStyle(.switch)
                .disabled(editedStart == nil)
            }

            if let binding = startBinding {
                DatePicker(selection: binding, displayedComponents: editedIsAllDay ? [.date] : [.date, .hourAndMinute]) {
                    Text(L10n.AIInline.start)
                }
                .datePickerStyle(.compact)
            } else {
                Button(L10n.AIInline.addStart) {
                    let now = roundedDate(Date())
                    editedStart = now
                    if editedIsAllDay {
                        let dayStart = Calendar.current.startOfDay(for: now)
                        editedStart = dayStart
                        editedEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
                    } else {
                        editedEnd = now.addingTimeInterval(defaultDuration)
                    }
                    syncPayload()
                }
                .buttonStyle(.bordered)
            }

            if !editedIsAllDay {
                if let endBinding = endBinding {
                    DatePicker(selection: endBinding, displayedComponents: [.date, .hourAndMinute]) {
                        Text(L10n.AIInline.end)
                    }
                    .datePickerStyle(.compact)
                } else if editedStart != nil {
                    Button(L10n.AIInline.addEnd) {
                        let base = editedStart ?? roundedDate(Date())
                        editedEnd = base.addingTimeInterval(defaultDuration)
                        syncPayload()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(L10n.Common.cancel, role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
            Button(L10n.Common.save) {
                syncPayload()
                onConfirm()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var advancedEditorButton: some View {
        if let handler = onOpenTaskEditor, supportsTaskEditor {
            Button {
                handler(action)
            } label: {
                Label(L10n.AIInline.openTaskEditor, systemImage: "square.and.pencil")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        } else if let handler = onOpenEventEditor, supportsEventEditor {
            Button {
                handler(action)
            } label: {
                Label(L10n.AIInline.openEventEditor, systemImage: "calendar")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }

    private var otherItems: [PreviewItem] {
        action.payload.compactMap { key, value in
            guard !handledKeys.contains(key), let display = displayValue(value) else { return nil }
            return PreviewItem(key: key, title: displayKey(key), value: display)
        }
        .sorted { lhs, rhs in
            if ranking(for: lhs.key) == ranking(for: rhs.key) {
                return lhs.title < rhs.title
            }
            return ranking(for: lhs.key) < ranking(for: rhs.key)
        }
    }

    private var actionColor: Color {
        switch action.type {
        case .createTask, .createEvent: return .green
        case .updateTask, .updateEvent: return .blue
        case .deleteTask, .deleteEvent: return .red
        case .suggestTimeSlots, .prioritizeTasks: return .blue
        case .requestClarification: return .orange
        case .showError: return .red
        }
    }

    private var supportsScheduleControls: Bool {
        action.payload.keys.contains("start") || action.payload.keys.contains("end") || action.type == .createEvent || action.type == .createTask
    }

    private var showNotesField: Bool {
        action.type == .createTask || action.type == .createEvent || !editedNotes.isEmpty
    }

    private var supportsTaskEditor: Bool {
        action.type == .createTask || action.type == .updateTask
    }

    private var supportsEventEditor: Bool {
        action.type == .createEvent || action.type == .updateEvent
    }

    private var priorityBinding: Binding<Int>? {
        guard let initial = editedPriority else { return nil }
        return Binding(
            get: { editedPriority ?? initial },
            set: { newValue in
                editedPriority = max(0, min(newValue, 3))
            }
        )
    }

    private var startBinding: Binding<Date>? {
        guard editedStart != nil else { return nil }
        return Binding(
            get: { editedStart ?? roundedDate(Date()) },
            set: { newValue in
                editedStart = newValue
                if let end = editedEnd, end <= newValue {
                    if editedIsAllDay {
                        let dayStart = Calendar.current.startOfDay(for: newValue)
                        editedStart = dayStart
                        editedEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
                    } else {
                        editedEnd = newValue.addingTimeInterval(defaultDuration)
                    }
                }
                syncPayload()
            }
        )
    }

    private var endBinding: Binding<Date>? {
        guard editedEnd != nil else { return nil }
        return Binding(
            get: { editedEnd ?? ((editedStart ?? roundedDate(Date())).addingTimeInterval(defaultDuration)) },
            set: { newValue in
                guard let start = editedStart else {
                    editedEnd = newValue
                    syncPayload()
                    return
                }
                if newValue <= start {
                    editedEnd = start.addingTimeInterval(defaultDuration)
                } else {
                    editedEnd = newValue
                }
                syncPayload()
            }
        )
    }

    private func seedFromAction() {
        isSyncingFromAction = true
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
        } else {
            editedPriority = nil
        }
        isSyncingFromAction = false
        syncPayload()
    }

    private func syncPayload() {
        guard !isSyncingFromAction else { return }
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            action.payload.removeValue(forKey: "title")
        } else {
            action.payload["title"] = trimmedTitle
        }

        let trimmedNotes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNotes.isEmpty {
            action.payload.removeValue(forKey: "notes")
        } else {
            action.payload["notes"] = trimmedNotes
        }

        if let start = editedStart {
            action.payload["start"] = start
        } else {
            action.payload.removeValue(forKey: "start")
        }

        if let end = editedEnd {
            action.payload["end"] = end
        } else {
            action.payload.removeValue(forKey: "end")
        }

        if editedIsAllDay {
            action.payload["is_all_day"] = true
        } else {
            action.payload.removeValue(forKey: "is_all_day")
        }

        if let priority = editedPriority {
            action.payload["priority"] = priority
        } else {
            action.payload.removeValue(forKey: "priority")
        }
    }

    private func adjustForAllDayChange() {
        guard !isSyncingFromAction else { return }
        guard var start = editedStart else {
            if editedIsAllDay {
                let now = roundedDate(Date())
                let dayStart = Calendar.current.startOfDay(for: now)
                editedStart = dayStart
                editedEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            }
            syncPayload()
            return
        }

        if editedIsAllDay {
            let dayStart = Calendar.current.startOfDay(for: start)
            start = dayStart
            editedStart = dayStart
            editedEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
        } else {
            if let end = editedEnd, end.timeIntervalSince(start) >= 20 * 3600 {
                editedEnd = start.addingTimeInterval(defaultDuration)
            } else if editedEnd == nil {
                editedEnd = start.addingTimeInterval(defaultDuration)
            }
        }
        syncPayload()
    }

    private func clearSchedule() {
        editedStart = nil
        editedEnd = nil
        editedIsAllDay = false
        syncPayload()
    }

    private func displayKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func ranking(for key: String) -> Int {
        let order = ["title", "start", "begin", "end", "dueDate", "is_all_day", "priority", "notes", "estimated_duration", "suggested_tags", "confidence"]
        return order.firstIndex(of: key) ?? order.count
    }

    private func displayValue(_ value: Any) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let date = value as? Date {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let bool = value as? Bool { return bool ? L10n.Common.yes : L10n.Common.no }
        if let array = value as? [String] { return array.joined(separator: ", ") }
        if let array = value as? [Any] {
            let values = array.compactMap { displayValue($0) }
            return values.isEmpty ? nil : values.joined(separator: ", ")
        }
        if let dict = value as? [String: Any] {
            let pairs = dict.compactMap { key, value -> String? in
                guard let display = displayValue(value) else { return nil }
                return "\(key): \(display)"
            }
            return pairs.isEmpty ? nil : pairs.joined(separator: ", ")
        }
        return String(describing: value)
    }

    private func priorityLabel(for value: Int) -> String {
        switch value {
        case 0: return L10n.Priority.none
        case 1: return L10n.Priority.low
        case 2: return L10n.Priority.medium
        default: return L10n.Priority.high
        }
    }

    private func roundedDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if let minute = components.minute {
            let roundedMinute = (minute / 5) * 5
            return calendar.date(from: DateComponents(year: components.year, month: components.month, day: components.day, hour: components.hour, minute: roundedMinute)) ?? date
        }
        return date
    }
}

private struct PreviewItem: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let value: String
}
