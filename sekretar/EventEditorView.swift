#if os(iOS)
import SwiftUI
import CoreData

struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var title: String
    @State private var notes: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var showingDeleteAlert = false
    @State private var isNewEvent: Bool
    @State private var isSaving = false

    let event: EventEntity

    init(event: EventEntity) {
        self.event = event
        let defaultStart = event.startDate ?? Date().addingTimeInterval(3600)
        let defaultEnd = event.endDate ?? defaultStart.addingTimeInterval(3600)

        _title = State(initialValue: event.title ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultEnd)
        _isAllDay = State(initialValue: event.isAllDay)
        _isNewEvent = State(initialValue: event.startDate == nil && (event.title ?? "").isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        headerSection
                        titleSection
                        scheduleSection
                        notesSection

                        if !isNewEvent {
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
                    Button(L10n.Common.cancel) { cancelEditing() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Button(L10n.Common.done) { save() }
                            .foregroundColor(canSave ? DesignSystem.Colors.primaryBlue : DesignSystem.Colors.textTertiary)
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .alert(L10n.Calendar.deleteEventConfirmation, isPresented: $showingDeleteAlert) {
                Button(L10n.Common.cancel, role: .cancel) { }
                Button(L10n.Common.delete, role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text(L10n.Calendar.deleteEventMessage)
            }
            .onDisappear { cleanupIfNeeded() }
        }
        .onChange(of: startDate) { _ in ensureValidRange() }
        .onChange(of: endDate) { _ in ensureValidRange() }
        .onChange(of: isAllDay) { _ in adjustForAllDayFlag() }
    }

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: isNewEvent ? "calendar.badge.plus" : "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundColor(DesignSystem.Colors.primaryBlue)
                .symbolEffect(.pulse, isActive: isNewEvent)

            Text(isNewEvent ? L10n.Calendar.newEvent : L10n.Calendar.editEvent)
                .font(DesignSystem.Typography.title1)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if let created = event.startDate {
                Text(created.formatted(date: .abbreviated, time: .shortened))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(L10n.Calendar.eventTitle, systemImage: "text.cursor")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            TextField(L10n.Calendar.eventTitlePlaceholder, text: $title)
                .textFieldStyle(.plain)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(color: DesignSystem.Shadow.small.color,
                        radius: DesignSystem.Shadow.small.radius,
                        x: DesignSystem.Shadow.small.x,
                        y: DesignSystem.Shadow.small.y)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Label(L10n.Calendar.eventTime, systemImage: "clock")
                    .font(DesignSystem.Typography.cardTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isAllDay.animation(DesignSystem.Animation.standard))
                    .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.primaryBlue))
                    .labelsHidden()
            }

            DatePicker(
                L10n.Calendar.startDate,
                selection: Binding(get: { startDate }, set: { startDate = $0 }),
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y)

            DatePicker(
                L10n.Calendar.endDate,
                selection: Binding(get: { endDate }, set: { endDate = $0 }),
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(L10n.Calendar.notes, systemImage: "note.text")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            TextEditor(text: $notes)
                .frame(minHeight: 120)
                .padding(DesignSystem.Spacing.md - 4)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(color: DesignSystem.Shadow.small.color,
                        radius: DesignSystem.Shadow.small.radius,
                        x: DesignSystem.Shadow.small.x,
                        y: DesignSystem.Shadow.small.y)
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) { showingDeleteAlert = true } label: {
            HStack {
                Spacer()
                Label(L10n.Common.delete, systemImage: "trash")
                    .font(DesignSystem.Typography.buttonText)
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .foregroundColor(.white)
            .background(DesignSystem.Colors.overdue)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    private func save() {
        guard canSave else { return }
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current

        let normalizedStart = isAllDay ? calendar.startOfDay(for: startDate) : startDate
        var normalizedEnd = isAllDay ? calendar.startOfDay(for: endDate) : endDate
        if normalizedEnd <= normalizedStart {
            normalizedEnd = isAllDay ? calendar.date(byAdding: .day, value: 1, to: normalizedStart) ?? normalizedStart.addingTimeInterval(86400) : normalizedStart.addingTimeInterval(1800)
        }

        event.title = trimmedTitle
        event.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        event.isAllDay = isAllDay
        event.startDate = normalizedStart
        event.endDate = normalizedEnd
        event.id = event.id ?? UUID()

        do {
            try context.save()
            Task { try? await EventKitService(context: context).syncToEventKit(event) }
#if canImport(UIKit)
            notify(.success)
#endif
            dismiss()
        } catch {
#if canImport(UIKit)
            notify(.error)
#endif
        }

        isSaving = false
    }

    private func deleteEvent() {
        let service = EventKitService(context: context)
        if let eventKitId = event.eventKitId {
            Task { try? await service.deleteFromEventKit(eventKitId: eventKitId) }
        }
        context.delete(event)
        try? context.save()
#if canImport(UIKit)
        notify(.success)
#endif
        dismiss()
    }

    private func cancelEditing() {
        cleanupIfNeeded()
        dismiss()
    }

    private func cleanupIfNeeded() {
        if isNewEvent && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(event)
            try? context.save()
        }
    }

    private func ensureValidRange() {
        if isAllDay {
            let calendar = Calendar.current
            startDate = calendar.startOfDay(for: startDate)
            endDate = calendar.startOfDay(for: endDate)
        }
        if endDate <= startDate {
            endDate = startDate.addingTimeInterval(isAllDay ? 86400 : 1800)
        }
    }

    private func adjustForAllDayFlag() {
        let calendar = Calendar.current
        if isAllDay {
            startDate = calendar.startOfDay(for: startDate)
            endDate = calendar.startOfDay(for: max(endDate, startDate.addingTimeInterval(86400)))
        }
    }
#if canImport(UIKit)

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
#endif
}

#Preview {
    let ctx = PersistenceController.preview().container.viewContext
    let sample = EventEntity(context: ctx)
    sample.id = UUID()
    sample.title = "Встреча"
    sample.startDate = Date()
    sample.endDate = Date().addingTimeInterval(3600)
    return EventEditorView(event: sample)
        .environment(\.managedObjectContext, ctx)
}
#else
import SwiftUI
import CoreData

struct EventEditorView: View {
    let event: EventEntity

    var body: some View {
        VStack(spacing: 12) {
            Text("Event editing is not available on this platform")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(event.title ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
#endif
