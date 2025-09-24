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
                .lineLimit(4)

            if !action.payload.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(previewItems.prefix(4)) { item in
                        HStack {
                            Text(item.title)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(item.value)
                                .lineLimit(2)
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

    private var previewItems: [PreviewItem] {
        action.payload.compactMap { key, value in
            guard let display = displayValue(value) else { return nil }
            return PreviewItem(key: key, title: displayKey(key), value: display)
        }
        .sorted { lhs, rhs in
            if ranking(for: lhs.key) == ranking(for: rhs.key) {
                return lhs.title < rhs.title
            }
            return ranking(for: lhs.key) < ranking(for: rhs.key)
        }
    }

    private func displayKey(_ k: String) -> String { k.replacingOccurrences(of: "_", with: " ").capitalized }

    private func ranking(for key: String) -> Int {
        let order = ["title", "start", "begin", "end", "dueDate", "is_all_day", "priority", "notes", "estimated_duration", "suggested_tags", "confidence"]
        return order.firstIndex(of: key) ?? order.count
    }

    private func displayValue(_ v: Any) -> String? {
        if let s = v as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let d = v as? Date { return d.formatted(date: .abbreviated, time: .shortened) }
        if let n = v as? NSNumber { return n.stringValue }
        if let b = v as? Bool { return b ? "Да" : "Нет" }
        if let array = v as? [String] { return array.joined(separator: ", ") }
        if let array = v as? [Any] {
            let values = array.compactMap { displayValue($0) }
            return values.isEmpty ? nil : values.joined(separator: ", ")
        }
        if let dict = v as? [String: Any] {
            let pairs = dict.compactMap { key, value -> String? in
                guard let display = displayValue(value) else { return nil }
                return "\(key): \(display)"
            }
            return pairs.isEmpty ? nil : pairs.joined(separator: ", ")
        }
        return String(describing: v)
    }
}

private struct PreviewItem: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let value: String
}
