import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let taskCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)
                
                if taskCount > 0 {
                    Circle()
                        .fill(DesignSystem.Colors.primaryBlue)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return DesignSystem.Colors.textTertiary
        } else if isSelected {
            return .white
        } else if isToday {
            return DesignSystem.Colors.primaryBlue
        } else {
            return DesignSystem.Colors.textPrimary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.primaryBlue
        } else if isToday {
            return DesignSystem.Colors.primaryBlue.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}