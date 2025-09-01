import SwiftUI

// MARK: - Model
struct Message: Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

// MARK: - ViewModel
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = [
        Message(text: "Привет! Я помогу спланировать день.", isUser: false),
        Message(text: "Добавь встречу завтра в 10:00 — созвон с дизайнером", isUser: true)
    ]
    @Published var input: String = ""
    @Published var typing: Bool = false

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(.init(text: trimmed, isUser: true))
        input = ""
        typing = true

        // Имитация ответа
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.messages.append(.init(text: "Поняла. Могу создать событие и напоминание.", isUser: false))
            self.typing = false
        }
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

                        // Якорь для автоскролла
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.top, 8)
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

                Button(action: vm.send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.96))
        }
        .navigationTitle("Чат")
    }
}

// MARK: - Preview
struct ChatScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ChatScreen() }
    }
}
