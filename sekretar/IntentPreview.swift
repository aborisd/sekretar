import SwiftUI

struct IntentPreview: View {
    let intent: AIIntent
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Group {
                    HStack { Text("Действие"); Spacer(); Text(intent.action).fontWeight(.semibold) }
                    if let p = intent.payload, !p.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(p.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary) }
                            }
                        }
                    } else {
                        Text("Нет параметров").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Уверенность"); Spacer()
                        Text(String(format: "%.0f%%", intent.meta.confidence * 100))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)

                Spacer()

                Button {
                    onConfirm()
                    dismiss()
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
}
