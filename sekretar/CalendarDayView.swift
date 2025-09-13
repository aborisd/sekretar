import SwiftUI
import EventKit

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let isCurrentMonth: Bool
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isToday {
            return .white
        } else if isSelected {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return .blue
        } else if isSelected {
            return .blue.opacity(0.2)
        } else {
            return .clear
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayFormatter.string(from: date))
                .font(.system(.body, design: .rounded))
                .fontWeight(isSelected || isToday ? .bold : .regular)
                .foregroundColor(textColor)
            
            // Event indicator
            if hasEvents {
                Circle()
                    .fill(isToday ? .white : .blue)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 40, height: 40)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? .blue : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    CalendarDayView(
        date: Date(), 
        isSelected: true, 
        isToday: false, 
        hasEvents: true, 
        isCurrentMonth: true
    )
}