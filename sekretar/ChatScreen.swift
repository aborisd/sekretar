import SwiftUI

// MARK: - Model
struct Message: Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

// MARK: - ViewModel
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = [
        Message(text: "Привет! Я помогу спланировать день.", isUser: false)
    ]
    @Published var input: String = ""
    @Published var typing: Bool = false

    private let ai = AIIntentService.shared
    var currentTask: Task<Void, Never>? = nil

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(.init(text: trimmed, isUser: true))
        input = ""
        typing = true
        currentTask?.cancel()
        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await ai.processUserInput(trimmed)
            self.typing = false
            self.currentTask = nil
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        typing = false
    }
}

// MARK: - Compact Bubble
private struct Bubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isUser ? Color.blue.opacity(0.14) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isUser ? Color.blue.opacity(0.25) : Color.black.opacity(0.08))
            )
    }
}

// MARK: - ChatScreen (полный файл)
struct ChatScreen: View {
    @StateObject private var vm = ChatViewModel()
    @ObservedObject private var ai = AIIntentService.shared
    @State private var showUndoBanner = false

    @StateObject private var voice = VoiceInputService()
    @State private var autoVoiceStarted = false

    var body: some View {
        VStack(spacing: 0) {
            // История
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.messages) { msg in
                            HStack(spacing: 0) {
                                if msg.isUser { Spacer(minLength: 0) }
                                Bubble(text: msg.text, isUser: msg.isUser)
                                    .frame(maxWidth: 280, alignment: msg.isUser ? .trailing : .leading)
                                if !msg.isUser { Spacer(minLength: 0) }
                            }
                            .frame(maxWidth: .infinity, alignment: msg.isUser ? .trailing : .leading)
                            .padding(.horizontal, 12)
                        }

                        if vm.typing {
                            HStack {
                                if (vm.messages.last?.isUser ?? false) { Spacer(minLength: 0) }
                                ProgressView().padding(.vertical, 4)
                                if !(vm.messages.last?.isUser ?? false) { Spacer(minLength: 0) }
                            }
                            .padding(.horizontal, 12)
                        }

                        // Встроенная карточка предпросмотра действия
                        if let action = ai.pendingAction {
                            AIActionInlineCard(
                                action: action,
                                onConfirm: {
                                    vm.currentTask?.cancel()
                                    vm.currentTask = Task { @MainActor in
                                        await ai.confirmPendingAction()
                                        await MainActor.run {
                                            self.vm.messages.append(.init(text: "✅ Изменения применены", isUser: false))
                                        }
                                        showUndoBanner = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                            withAnimation { showUndoBanner = false }
                                        }
                                    }
                                },
                                onCancel: { ai.cancelPendingAction() }
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
                            .fill(Color(.systemBackground))
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

                Button(action: vm.send) {
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
        .task {
            // Автостарт голосового ввода по умолчанию один раз при открытии чата
            if !autoVoiceStarted {
                autoVoiceStarted = true
                if !voice.isRecording { await voice.start() }
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
            // Показать реплику пользователя
            vm.messages.append(.init(text: text, isUser: true))
            vm.input = ""
            vm.typing = true
            vm.currentTask?.cancel()
            vm.currentTask = Task { @MainActor in
                await ai.processUserInput(text)
                vm.typing = false
                voice.reset()
            }
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
                vm.messages.append(.init(text: toast, isUser: false))
            }
        }
    }
}

// MARK: - Preview
struct ChatScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ChatScreen() }
    }
}
