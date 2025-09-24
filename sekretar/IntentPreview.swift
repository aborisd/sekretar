import SwiftUI

// Legacy view kept for compatibility; now previews AIAction
struct IntentPreview: View {
    let action: AIAction
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Group {
                    HStack {
                        Text("Действие"); Spacer()
                        Text(action.type.displayName).fontWeight(.semibold)
                    }
                    if !action.payload.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sortedPayload(), id: \.0) { k, v in
                                HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary) }
                            }
                        }
                    } else {
                        Text("Нет параметров").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Уверенность"); Spacer()
                        Text(String(format: "%.0f%%", action.confidence * 100)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)

                Spacer()

                Button {
                    onConfirm(); dismiss()
                } label: {
                    Label("Подтвердить", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button("Отмена") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Предпросмотр")
            .presentationDetents([.medium, .large])
        }
    }

    private func sortedPayload() -> [(String, String)] {
        action.payload
            .map { key, value in (key, String(describing: value)) }
            .sorted { $0.0 < $1.0 }
    }
}
