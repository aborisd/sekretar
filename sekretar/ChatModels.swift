import Foundation

struct ChatMessage: Identifiable, Hashable {
    enum Author: Hashable {
        case user
        case assistant
        case system
    }

    enum Style: Hashable {
        case bubble
        case assistantCard
        case banner
    }

    let id: UUID
    let author: Author
    var style: Style
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), author: Author, text: String, timestamp: Date = Date(), style: Style? = nil) {
        self.id = id
        self.author = author
        self.text = text
        self.timestamp = timestamp
        self.style = style ?? ChatMessage.defaultStyle(for: author)
    }

    var isUser: Bool { author == .user }

    private static func defaultStyle(for author: Author) -> Style {
        switch author {
        case .assistant: return .bubble
        case .system: return .banner
        case .user: return .bubble
        }
    }
}
