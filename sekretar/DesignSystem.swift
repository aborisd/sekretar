import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary Colors - AI Theme
        static let primaryBlue = Color(red: 0.1, green: 0.4, blue: 0.9)
        static let primaryOrange = Color(red: 0.9, green: 0.5, blue: 0.1)
        static let primaryTeal = Color(red: 0.0, green: 0.7, blue: 0.6)
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primaryBlue, primaryOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let secondaryGradient = LinearGradient(
            colors: [primaryTeal, primaryBlue],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let successGradient = LinearGradient(
            colors: [Color.green.opacity(0.8), Color.green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let warningGradient = LinearGradient(
            colors: [Color.orange.opacity(0.8), Color.orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Background Colors
        static let background = Color(.systemGroupedBackground)
        static let secondaryBackground = Color(.secondarySystemGroupedBackground)
        static let cardBackground = Color(.systemBackground)
        
        // Semantic Colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        
        // Priority Colors
        static let priorityHigh = Color.red
        static let priorityMedium = Color.orange
        static let priorityLow = Color.blue
        static let priorityNone = Color.gray
        
        // Status Colors
        static let completed = Color.green
        static let pending = Color.orange
        static let overdue = Color.red
    }
    
    // MARK: - Typography
    struct Typography {
        // Display
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        
        // Body
        static let bodyLarge = Font.body.weight(.medium)
        static let body = Font.body
        static let bodySmall = Font.callout
        
        // Supporting
        static let caption = Font.caption
        static let footnote = Font.footnote
        
        // Custom
        static let cardTitle = Font.headline.weight(.semibold)
        static let cardSubtitle = Font.subheadline.weight(.regular)
        static let buttonText = Font.body.weight(.semibold)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let circle: CGFloat = 50
    }
    
    // MARK: - Shadow
    struct Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: 4.0, x: 0.0, y: 2.0)
        static let medium = (color: Color.black.opacity(0.15), radius: 8.0, x: 0.0, y: 4.0)
        static let large = (color: Color.black.opacity(0.2), radius: 12.0, x: 0.0, y: 6.0)
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.22)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let bouncy = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.85)
    }
}

// MARK: - View Modifiers
struct EnhancedCardStyle: ViewModifier {
    let isPressed: Bool
    
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: DesignSystem.Shadow.medium.color,
                radius: isPressed ? DesignSystem.Shadow.small.radius : DesignSystem.Shadow.medium.radius,
                x: DesignSystem.Shadow.medium.x,
                y: isPressed ? DesignSystem.Shadow.small.y : DesignSystem.Shadow.medium.y
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .shadow(
                color: DesignSystem.Shadow.small.color,
                radius: DesignSystem.Shadow.small.radius,
                x: DesignSystem.Shadow.small.x,
                y: DesignSystem.Shadow.small.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonText)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.primaryGradient)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(
                color: DesignSystem.Shadow.medium.color,
                radius: configuration.isPressed ? DesignSystem.Shadow.small.radius : DesignSystem.Shadow.medium.radius,
                x: DesignSystem.Shadow.medium.x,
                y: configuration.isPressed ? DesignSystem.Shadow.small.y : DesignSystem.Shadow.medium.y
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonText)
            .foregroundColor(DesignSystem.Colors.primaryBlue)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.primaryBlue, lineWidth: 1.5)
            )
            .shadow(
                color: DesignSystem.Shadow.small.color,
                radius: DesignSystem.Shadow.small.radius,
                x: DesignSystem.Shadow.small.x,
                y: DesignSystem.Shadow.small.y
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func enhancedCard(isPressed: Bool = false) -> some View {
        self.modifier(EnhancedCardStyle(isPressed: isPressed))
    }
    
    func glassCard() -> some View {
        self.modifier(GlassCardStyle())
    }
    
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func shimmer() -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(30))
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: UUID()
                )
        )
        .clipped()
    }
    
    func priorityColor(_ priority: Int16) -> Color {
        switch priority {
        case 3: return DesignSystem.Colors.priorityHigh
        case 2: return DesignSystem.Colors.priorityMedium
        case 1: return DesignSystem.Colors.priorityLow
        default: return DesignSystem.Colors.priorityNone
        }
    }
}

// MARK: - Custom Views
struct GradientHeader: View {
    let title: String
    let subtitle: String?
    
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.primaryGradient)
    }
}

struct PriorityBadge: View {
    let priority: Int16
    
    var body: some View {
        if priority > 0 {
            Text("P\(priority)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(priorityColor(priority))
                )
        }
    }
}

struct StatusIndicator: View {
    let isCompleted: Bool
    let isOverdue: Bool
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    private var statusColor: Color {
        if isCompleted {
            return DesignSystem.Colors.completed
        } else if isOverdue {
            return DesignSystem.Colors.overdue
        } else {
            return DesignSystem.Colors.pending
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .primaryButton()
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Loading States
struct LoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
                .cornerRadius(4)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 16)
                .cornerRadius(4)
            
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 12)
                    .cornerRadius(4)
                
                Spacer()
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 12)
                    .cornerRadius(4)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .enhancedCard()
        .shimmer()
    }
}
