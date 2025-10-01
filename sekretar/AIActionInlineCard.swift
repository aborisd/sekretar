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
    private let handledKeys: Set<String> = [
        "title", "notes", "start", "end", "is_all_day", "priority", "category", "estimated_duration", "suggested_tags"
    ]

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
        VStack(alignment: .leading, spacing: 16) {
            header

            if !highlightChips.isEmpty {
                highlightsSection
            }

            descriptionSection

            if !quickActions.isEmpty {
                quickActionsSection
            }

            editableFields

            if !otherItems.isEmpty {
                Divider().padding(.vertical, 4)
                payloadSection
            }

            actionButtons
        }
        .padding(18)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .onAppear { seedFromAction() }
        .onChange(of: action.id) { _ in seedFromAction() }
        .onChange(of: editedTitle) { _ in syncPayload() }
        .onChange(of: editedNotes) { _ in syncPayload() }
        .onChange(of: editedStart) { _ in syncPayload() }
        .onChange(of: editedEnd) { _ in syncPayload() }
        .onChange(of: editedPriority) { _ in syncPayload() }
        .onChange(of: editedIsAllDay) { _ in adjustForAllDayChange() }
    }

    // MARK: - Header & Summary

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: action.type.icon)
                    .foregroundStyle(actionColor)
                    .font(.system(size: 20, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(actionTypeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(action.title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                confidenceBadge
                confirmationBadge
            }
        }
    }

    private var descriptionSection: some View {
        Text(action.description)
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(actionColor.opacity(0.06))
            )
    }

    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickActions) { action in
                    Button(action: action.perform) {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .imageScale(.medium)
                            Text(action.title)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(action.tint.opacity(0.16))
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(action.tint)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
        )
    }

    private var highlightsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(highlightChips) { chip in
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: chip.icon)
                        .imageScale(.medium)
                        .foregroundStyle(chip.tint)
                    Text(chip.text)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(chip.tint.opacity(0.12))
                )
            }
        }
    }

    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(otherItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(role: .cancel, action: onCancel) {
                Label(L10n.Common.cancel, systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)

            Button {
                syncPayload()
                onConfirm()
            } label: {
                Label(L10n.Common.save, systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .tint(actionColor)
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

    // MARK: - Editable fields

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
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.2))
                    )
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

    // MARK: - Derived data

    private var highlightChips: [InlineChip] {
        var chips: [InlineChip] = []

        if let start = editedStart {
            let title: String
            if editedIsAllDay {
                title = Self.dayFormatter.string(from: start)
            } else {
                let datePart = Self.dayFormatter.string(from: start)
                let timePart = Self.timeFormatter.string(from: start)
                title = "\(datePart), \(timePart)"
            }
            chips.append(.init(icon: editedIsAllDay ? "calendar" : "clock", text: title, tint: actionColor))
        }

        if let end = editedEnd, !editedIsAllDay, let start = editedStart, end > start {
            let timePart = Self.timeFormatter.string(from: end)
            chips.append(.init(icon: "clock.arrow.circlepath", text: durationText(from: start, to: end, fallbackTime: timePart), tint: actionColor))
        }

        if let priority = editedPriority {
            let tint = priorityTint(for: priority)
            chips.append(.init(icon: "flag.fill", text: priorityLabel(for: priority), tint: tint))
        }

        if let category = action.payload["category"] as? String, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chips.append(.init(icon: "square.grid.2x2", text: category.capitalized, tint: DesignSystem.Colors.primaryTeal))
        }

        if let durationMinutes = durationMinutesFromPayload {
            let text = formattedDuration(minutes: durationMinutes)
            chips.append(.init(icon: "hourglass", text: text, tint: DesignSystem.Colors.primaryBlue))
        }

        if let tags = action.payload["suggested_tags"] as? [String] {
            for tag in tags.prefix(2) {
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                chips.append(.init(icon: "number", text: "#\(trimmed)", tint: DesignSystem.Colors.textSecondary))
            }
        }

        return chips
    }

    private var quickActions: [QuickActionItem] {
        var actions: [QuickActionItem] = []

        if editedStart != nil {
            if !editedIsAllDay {
                actions.append(QuickActionItem(
                    title: isRussian ? "−30 мин" : "−30 min",
                    icon: "clock.arrow.circlepath",
                    tint: DesignSystem.Colors.primaryBlue,
                    perform: { shiftSchedule(by: -1800) }
                ))
                actions.append(QuickActionItem(
                    title: isRussian ? "+30 мин" : "+30 min",
                    icon: "clock.arrow.circlepath",
                    tint: DesignSystem.Colors.primaryBlue,
                    perform: { shiftSchedule(by: 1800) }
                ))
            }
            actions.append(QuickActionItem(
                title: isRussian ? "Завтра" : "Tomorrow",
                icon: "calendar.badge.plus",
                tint: DesignSystem.Colors.primaryTeal,
                perform: { moveSchedule(days: 1) }
            ))

            if !editedIsAllDay {
                actions.append(QuickActionItem(
                    title: isRussian ? "Весь день" : "All-day",
                    icon: "sun.max",
                    tint: DesignSystem.Colors.priorityMedium,
                    perform: { setAllDay(true) }
                ))
            } else {
                actions.append(QuickActionItem(
                    title: isRussian ? "Время" : "Timed",
                    icon: "clock",
                    tint: DesignSystem.Colors.textSecondary,
                    perform: { setAllDay(false) }
                ))
            }
        }

        if action.type == .createTask || action.type == .updateTask {
            actions.append(contentsOf: quickPriorityActions())
        }

        return actions
    }

    private var durationMinutesFromPayload: Int? {
        if let intValue = action.payload["estimated_duration"] as? Int { return intValue }
        if let doubleValue = action.payload["estimated_duration"] as? Double { return Int(doubleValue) }
        return nil
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

    private var borderColor: Color { actionColor.opacity(0.18) }

    private var actionTypeLabel: String {
        switch action.type {
        case .createTask: return L10n.AIActionText.createTaskTitle
        case .updateTask: return L10n.AIActionText.updateTaskTitle
        case .deleteTask: return L10n.AIActionText.deleteTaskTitle
        case .createEvent: return L10n.AIActionText.createEventTitle
        case .updateEvent: return L10n.AIActionText.updateEventTitle
        case .deleteEvent: return L10n.AIActionText.deleteEventTitle
        case .suggestTimeSlots: return L10n.AIActionText.scheduleTaskTitle
        case .prioritizeTasks: return "AI Prioritization"
        case .requestClarification: return L10n.AIActionText.clarificationTitle
        case .showError: return "AI Error"
        }
    }

    private var confidenceBadge: some View {
        let percent = Int((action.confidence * 100).rounded())
        return Label("\(percent)%", systemImage: "sparkles")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(actionColor.opacity(0.16))
            )
            .foregroundStyle(actionColor)
    }

    @ViewBuilder
    private var confirmationBadge: some View {
        if action.requiresConfirmation {
            Label(isRussian ? "Нужно подтвердить" : "Needs review", systemImage: "hand.raised")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.16))
                )
                .foregroundStyle(Color.orange)
        } else {
            Label(isRussian ? "Авто" : "Auto", systemImage: "bolt.fill")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(0.18))
                )
                .foregroundStyle(Color.green)
        }
    }

    private var actionColor: Color {
        switch action.type {
        case .createTask, .createEvent: return DesignSystem.Colors.primaryTeal
        case .updateTask, .updateEvent: return DesignSystem.Colors.primaryBlue
        case .deleteTask, .deleteEvent: return DesignSystem.Colors.priorityHigh
        case .suggestTimeSlots, .prioritizeTasks: return DesignSystem.Colors.primaryBlue
        case .requestClarification: return Color.orange
        case .showError: return Color.red
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

    // MARK: - Sync helpers

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

    private func shiftSchedule(by interval: TimeInterval) {
        guard let start = editedStart else { return }
        let newStart = start.addingTimeInterval(interval)
        editedStart = newStart
        if let end = editedEnd {
            editedEnd = end.addingTimeInterval(interval)
        } else {
            editedEnd = newStart.addingTimeInterval(defaultDuration)
        }
        editedIsAllDay = false
        syncPayload()
    }

    private func moveSchedule(days: Int) {
        guard let start = editedStart else { return }
        let calendar = Calendar.current
        if editedIsAllDay {
            if let shifted = calendar.date(byAdding: .day, value: days, to: start) {
                editedStart = calendar.startOfDay(for: shifted)
                editedEnd = calendar.date(byAdding: .day, value: 1, to: editedStart ?? shifted)
            }
        } else {
            let interval = TimeInterval(days * 86400)
            editedStart = start.addingTimeInterval(interval)
            if let end = editedEnd {
                editedEnd = end.addingTimeInterval(interval)
            }
        }
        syncPayload()
    }

    private func setAllDay(_ value: Bool) {
        guard editedStart != nil else { return }
        editedIsAllDay = value
        adjustForAllDayChange()
    }

    private func quickPriorityActions() -> [QuickActionItem] {
        let titles: [(Int, String, Color)] = [
            (3, isRussian ? "Высокий" : "High", DesignSystem.Colors.priorityHigh),
            (2, isRussian ? "Средний" : "Medium", DesignSystem.Colors.priorityMedium),
            (1, isRussian ? "Низкий" : "Low", DesignSystem.Colors.priorityLow)
        ]

        return titles.map { value, title, tint in
            QuickActionItem(
                title: title,
                icon: "flag.fill",
                tint: tint,
                perform: {
                    editedPriority = value
                    syncPayload()
                }
            )
        }
    }

    // MARK: - Formatting helpers

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

    private func priorityTint(for value: Int) -> Color {
        switch value {
        case 3: return DesignSystem.Colors.priorityHigh
        case 2: return DesignSystem.Colors.priorityMedium
        case 1: return DesignSystem.Colors.priorityLow
        default: return DesignSystem.Colors.priorityNone
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

    private func formattedDuration(minutes: Int) -> String {
        if minutes <= 0 { return isRussian ? "Без длительности" : "No duration" }
        if minutes % 60 == 0 {
            let hours = minutes / 60
            let unit = isRussian ? "ч" : "h"
            return "\(hours) \(unit)"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            if isRussian {
                return "\(hours) ч \(mins) мин"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
        if isRussian {
            return "\(mins) мин"
        }
        return "\(mins)m"
    }

    private func durationText(from start: Date, to end: Date, fallbackTime: String) -> String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes <= 0 { return fallbackTime }
        return formattedDuration(minutes: minutes)
    }

    private var isRussian: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") ?? Locale.current.identifier.lowercased().hasPrefix("ru")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "d MMMM"
        return formatter
    }()
}

private struct PreviewItem: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let value: String
}

private struct InlineChip: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let tint: Color
}

private struct QuickActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let perform: () -> Void
}
