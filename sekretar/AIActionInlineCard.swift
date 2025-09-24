import SwiftUI

struct AIActionInlineCard: View {
    let action: AIAction
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: action.type.icon)
                    .foregroundStyle(actionColor)
                Text(action.title)
                    .font(.headline)
            }
            .padding(.bottom, 2)

            Text(action.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !action.payload.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(previewItems.prefix(4), id: \.0) { key, val in
                        HStack {
                            Text(key).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(val)
                        }
                        .font(.caption)
                    }
                    if previewItems.count > 4 {
                        Text("…и ещё \(previewItems.count - 4)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Отмена", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                Button("Подтвердить", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var previewItems: [(String, String)] {
        action.payload.map { k, v in (displayKey(k), displayValue(v)) }.sorted { $0.0 < $1.0 }
    }

    private func displayKey(_ k: String) -> String { k.replacingOccurrences(of: "_", with: " ").capitalized }

    private func displayValue(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let d = v as? Date { return d.formatted(date: .abbreviated, time: .shortened) }
        if let n = v as? NSNumber { return n.stringValue }
        if let b = v as? Bool { return b ? "Да" : "Нет" }
        return String(describing: v)
    }
}

