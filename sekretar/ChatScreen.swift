import SwiftUI
import CoreData

// MARK: - ViewModel
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(author: .assistant, text: "Привет! Я помогу спланировать день.")
    ]
    @Published var input: String = ""
    @Published var typing: Bool = false
    @Published var isAIEnabled: Bool = false

    private let ai = AIIntentService.shared
    var currentTask: Task<Void, Never>? = nil

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(author: .user, text: trimmed))
        input = ""
        typing = isAIEnabled
        currentTask?.cancel()
        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.typing = false
                self.currentTask = nil
            }

            if self.isAIEnabled {
                do {
                    let reply = try await self.ai.chatResponse(for: trimmed)
                    guard !Task.isCancelled else { return }
                    self.messages.append(ChatMessage(author: .assistant, text: reply))
                } catch {
                    guard !Task.isCancelled else { return }
                    self.messages.append(ChatMessage(author: .system, text: "Не удалось получить ответ от ИИ."))
                }
            }

            if !Task.isCancelled {
                await self.ai.processUserInput(trimmed)
            }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        typing = false
    }

    func toggleAIMode() {
        isAIEnabled.toggle()
        let status = isAIEnabled ? "ИИ-режим включен" : "ИИ-режим выключен"
        messages.append(ChatMessage(author: .system, text: status, style: .banner))
    }
}

// MARK: - Compact Bubble
private struct Bubble: View {
    let message: ChatMessage

    var body: some View {
        Text(message.text)
            .font(.system(size: 15))
            .foregroundColor(textColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor)
            )
    }

    private var fillColor: Color {
        switch message.author {
        case .user:
            return Color.blue.opacity(0.14)
        case .assistant:
            return DesignSystem.Colors.cardBackground
        case .system:
            return Color.gray.opacity(0.18)
        }
    }

    private var strokeColor: Color {
        switch message.author {
        case .user:
            return Color.blue.opacity(0.25)
        case .assistant:
            return Color.black.opacity(0.08)
        case .system:
            return Color.gray.opacity(0.3)
        }
    }

    private var textColor: Color {
        message.author == .system ? .secondary : .primary
    }
}

// MARK: - ChatScreen (полный файл)
struct ChatScreen: View {
    @StateObject private var vm = ChatViewModel()
    @ObservedObject private var ai = AIIntentService.shared
    @State private var showUndoBanner = false
    @Environment(\.managedObjectContext) private var context
    @State private var taskEditorHandle: TaskEditorPresentation?
    @State private var eventEditorHandle: EventEditorPresentation?

    @StateObject private var voice = VoiceInputService()

    var body: some View {
        VStack(spacing: 0) {
            // История
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { message in
                            MessageRow(message: message)
                                .padding(.horizontal, 12)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if vm.typing {
                            HStack {
                                switch vm.messages.last?.author {
                                case .user?:
                                    Spacer(minLength: 0)
                                    ProgressView().padding(.vertical, 4)
                                case .assistant?:
                                    ProgressView().padding(.vertical, 4)
                                    Spacer(minLength: 0)
                                case .system?:
                                    Spacer(minLength: 0)
                                    ProgressView().padding(.vertical, 4)
                                    Spacer(minLength: 0)
                                case nil:
                                    ProgressView().padding(.vertical, 4)
                                }
                            }
                            .padding(.horizontal, 12)
                        }

                        // Встроенная карточка предпросмотра действия
                        if let pending = ai.pendingAction {
                            AIActionInlineCard(
                                action: Binding(
                                    get: { ai.pendingAction ?? pending },
                                    set: { ai.pendingAction = $0 }
                                ),
                                onConfirm: {
                                    vm.currentTask?.cancel()
                                    vm.currentTask = Task { @MainActor in
                                        await ai.confirmPendingAction()
                                        await MainActor.run {
                                            self.vm.messages.append(ChatMessage(author: .system, text: "✅ Изменения применены", style: .banner))
                                        }
                                        showUndoBanner = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                            withAnimation { showUndoBanner = false }
                                        }
                                    }
                                },
                                onCancel: { ai.cancelPendingAction() },
                                onOpenTaskEditor: { openTaskEditor(for: $0) },
                                onOpenEventEditor: { openEventEditor(for: $0) }
                            )
                            .padding(.horizontal, 12)
                        }

                        // Якорь для автоскролла
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.top, 8)
                    .task { await MaintenanceService.purgeEmptyDraftTasks(in: PersistenceController.shared.container.viewContext) }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .background(Color(white: 0.96))
            }

            Divider()

            // Ввод
            HStack(spacing: 8) {
                TextField("Напишите…", text: $vm.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08))
                    )
                    .lineLimit(1...5)

                if vm.typing || ai.isProcessing {
                    Button(action: vm.stop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: { 
                        vm.currentTask?.cancel()
                        vm.currentTask = Task { @MainActor in
                        if voice.isRecording {
                            await voice.stop()
                            let text = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                await ai.processUserInput(text)
                            }
                            voice.reset()
                            vm.input = ""
                        } else {
                            voice.reset()
                            vm.input = ""
                            await voice.start()
                        }
                    } }) {
                        Image(systemName: voice.isRecording ? "mic.circle.fill" : "mic.circle")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(ai.isProcessing)
                }

                // Кнопка структурного разбора/интента (предпросмотр действий)
                Button {
                    let text = vm.input.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    vm.currentTask?.cancel()
                    vm.currentTask = Task { @MainActor in await ai.processUserInput(text) }
                    // Сбрасываем поле ввода сразу после запуска анализа
                    vm.input = ""
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Button(action: {
                    if voice.isRecording {
                        Task { await voice.stop(); voice.reset() }
                    }
                    vm.send()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ai.isProcessing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.96))
        }
        .navigationTitle("Чат")
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: vm.toggleAIMode) {
                    Image(systemName: "brain.head.profile")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(vm.isAIEnabled ? .white : .blue)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(vm.isAIEnabled ? Color.blue : Color.blue.opacity(0.12))
                        )
                }
                .accessibilityLabel(vm.isAIEnabled ? "Отключить ИИ" : "Включить ИИ")
            }
        }
#endif
        // Раньше предпросмотр открывался как модалка; теперь он инлайн
        // Баннер Undo после применения расписания
        .overlay(alignment: .bottom) {
            if showUndoBanner {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Изменения применены")
                        .font(.subheadline)
                    Spacer()
                    Button("Отменить") {
                        Task { await ai.undoLastAppliedSchedule() }
                        withAnimation { showUndoBanner = false }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(item: $taskEditorHandle) { handle in
            TaskEditorView(task: handle.task)
                .environment(\.managedObjectContext, context)
                .onDisappear {
                    if !handle.isNew && handle.task.hasChanges {
                        context.refresh(handle.task, mergeChanges: false)
                    }
                }
        }
        .sheet(item: $eventEditorHandle) { handle in
            EventEditorView(event: handle.event)
                .environment(\.managedObjectContext, context)
                .onDisappear {
                    if !handle.isNew && handle.event.hasChanges {
                        context.refresh(handle.event, mergeChanges: false)
                    }
                }
        }
        // Обновляем поле ввода во время диктовки, и отправляем по завершении
        .onChange(of: voice.transcript) { newValue in
            if voice.isRecording {
                vm.input = newValue
            }
        }
        .onChange(of: voice.isRecording) { isRec in
            guard !isRec else { return }
            let text = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            vm.input = text
            vm.send()
            voice.reset()
        }
        .onChange(of: ai.pendingAction?.id) { _ in
            // Если появилась карточка предпросмотра — останавливаем запись, чтобы не было гонок состояний
            if ai.pendingAction != nil && voice.isRecording {
                Task { await voice.stop() }
            }
        }
        .onChange(of: ai.lastOpenLink?.id) { _ in
            guard let link = ai.lastOpenLink else { return }
            switch link.tab {
            case .calendar:
                NotificationCenter.default.post(name: .openCalendarOn, object: nil, userInfo: ["date": link.date as Any])
            case .tasks:
                NotificationCenter.default.post(name: .openTasksOn, object: nil)
            }
        }
        .onChange(of: ai.lastResultToast) { toast in
            if let toast, !toast.isEmpty {
                vm.messages.append(ChatMessage(author: .assistant, text: toast, style: .bubble))
            }
        }
    }

    private func openTaskEditor(for action: AIAction) {
        ai.cancelPendingAction()
        let resolved = resolveTask(from: action)
        let task: TaskEntity
        let isNew: Bool
        if let existing = resolved {
            task = existing
            isNew = false
        } else {
            task = createTaskDraft()
            isNew = true
        }
        applyTaskPayload(action.payload, to: task)
        vm.messages.append(ChatMessage(author: .system, text: "Открыл редактор задачи", style: .banner))
        taskEditorHandle = TaskEditorPresentation(task: task, isNew: isNew)
    }

    private func openEventEditor(for action: AIAction) {
        ai.cancelPendingAction()
        let resolved = resolveEvent(from: action)
        let event: EventEntity
        let isNew: Bool
        if let existing = resolved {
            event = existing
            isNew = false
        } else {
            event = createEventDraft()
            isNew = true
        }
        applyEventPayload(action.payload, to: event)
        vm.messages.append(ChatMessage(author: .system, text: "Открыл редактор события", style: .banner))
        eventEditorHandle = EventEditorPresentation(event: event, isNew: isNew)
    }

    private func resolveTask(from action: AIAction) -> TaskEntity? {
        if let uuid = payloadUUID(action.payload, key: "task_id"), let match = fetchTask(uuid: uuid) {
            return match
        }
        if let title = action.payload["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fetchTask(title: title)
        }
        return nil
    }

    private func resolveEvent(from action: AIAction) -> EventEntity? {
        if let uuid = payloadUUID(action.payload, key: "event_id"), let match = fetchEvent(uuid: uuid) {
            return match
        }
        if let title = action.payload["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fetchEvent(title: title)
        }
        return nil
    }

    private func fetchTask(uuid: UUID) -> TaskEntity? {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        return try? context.fetch(request).first
    }

    private func fetchTask(title: String) -> TaskEntity? {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", title)
        return try? context.fetch(request).first
    }

    private func fetchEvent(uuid: UUID) -> EventEntity? {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        return try? context.fetch(request).first
    }

    private func fetchEvent(title: String) -> EventEntity? {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", title)
        return try? context.fetch(request).first
    }

    private func createTaskDraft() -> TaskEntity {
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.createdAt = Date()
        task.updatedAt = Date()
        task.isCompleted = false
        task.priority = 1
        return task
    }

    private func createEventDraft() -> EventEntity {
        let event = EventEntity(context: context)
        event.id = UUID()
        let start = Calendar.current.nextDate(after: Date(), matching: DateComponents(minute: 0), matchingPolicy: .nextTimePreservingSmallerComponents) ?? Date().addingTimeInterval(1800)
        event.startDate = start
        event.endDate = start.addingTimeInterval(3600)
        event.isAllDay = false
        return event
    }

    private func applyTaskPayload(_ payload: [String: Any], to task: TaskEntity) {
        if let title = payload["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.title = title
        }
        if let notes = payload["notes"] as? String {
            task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let priority = payload["priority"] as? Int {
            task.priority = Int16(priority)
        } else if let number = payload["priority"] as? NSNumber {
            task.priority = number.int16Value
        }
        if let due = payload["start"] as? Date {
            task.dueDate = due
        } else if let end = payload["end"] as? Date {
            task.dueDate = end
        }
        task.updatedAt = Date()
    }

    private func applyEventPayload(_ payload: [String: Any], to event: EventEntity) {
        if let title = payload["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            event.title = title
        }
        if let notes = payload["notes"] as? String {
            event.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = payload["start"] as? Date {
            event.startDate = start
        }
        if let end = payload["end"] as? Date {
            event.endDate = end
        }
        if let isAllDay = payload["is_all_day"] as? Bool {
            event.isAllDay = isAllDay
        }
        if event.endDate == nil, let start = event.startDate {
            event.endDate = start.addingTimeInterval(3600)
        }
    }

    private func payloadUUID(_ payload: [String: Any], key: String) -> UUID? {
        if let idString = payload[key] as? String {
            return UUID(uuidString: idString)
        }
        if let uuid = payload[key] as? UUID {
            return uuid
        }
        return nil
    }
}

private struct TaskEditorPresentation: Identifiable {
    let id = UUID()
    let task: TaskEntity
    let isNew: Bool
}

private struct EventEditorPresentation: Identifiable {
    let id = UUID()
    let event: EventEntity
    let isNew: Bool
}

// MARK: - Message Row Variants
private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.style {
        case .assistantCard:
            AssistantTipCard(message: message)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .banner:
            SystemBannerMessage(message: message)
                .frame(maxWidth: .infinity)
        case .bubble:
            bubbleRow
        }
    }

    private var bubbleRow: some View {
        HStack(spacing: 0) {
            if message.isUser { Spacer(minLength: 0) }
            Bubble(message: message)
                .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

private struct SystemBannerMessage: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Label {
                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.gray.opacity(0.18))
            )
            Spacer(minLength: 0)
        }
    }
}

private struct AssistantTipCard: View {
    let message: ChatMessage
    @State private var isExpanded = false

    private var title: String {
        if let first = lines.first, first.count <= 80 {
            return first
        }
        return "Совет ассистента"
    }

    private var details: [String] {
        var remainder = lines
        if !remainder.isEmpty && remainder.first == title { remainder.removeFirst() }
        return remainder
    }

    private var lines: [String] {
        message.text
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.split(separator: "•").map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.primaryBlue, DesignSystem.Colors.primaryTeal.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title3.bold())
                    .foregroundStyle(Color.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.16))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Совет ассистента")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .textCase(.uppercase)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(DesignSystem.Animation.standard) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .opacity(details.isEmpty ? 0 : 1)
                .disabled(details.isEmpty)
            }

            if !details.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(detailLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(gradient)
                .shadow(color: DesignSystem.Colors.primaryBlue.opacity(0.18), radius: 10, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !details.isEmpty {
                withAnimation(DesignSystem.Animation.standard) { isExpanded.toggle() }
            }
        }
    }

    private var detailLines: [String] {
        if isExpanded || details.count <= 2 {
            return details
        }
        return Array(details.prefix(2))
    }
}

// MARK: - Preview
struct ChatScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ChatScreen() }
    }
}
