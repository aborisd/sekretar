import SwiftUI

struct SideMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userName = "User"
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with user profile
                headerSection
                
                Divider()
                
                // Menu items
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        menuItems
                    }
                }
                
                Spacer()
                
                // Footer
                footerSection
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Avatar
                Circle()
                    .fill(DesignSystem.Colors.primaryGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(userName.prefix(1).uppercased())
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userName)
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("user@example.com")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(DesignSystem.Colors.cardBackground)
    }
    
    private var menuItems: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(icon: "person.circle", title: "Редактировать профиль", action: {})
            MenuRow(icon: "envelope", title: "Изменить email", action: {})
            MenuRow(icon: "calendar.badge.plus", title: "Синхронизация календарей", action: {})
            MenuRow(icon: "icloud", title: "Google Calendar", action: {})
            MenuRow(icon: "calendar", title: "Outlook", action: {})
            MenuRow(icon: "applelogo", title: "Apple Calendar", action: {})
            Divider().padding(.vertical, 8)
            MenuRow(icon: "bell", title: "Уведомления", action: {})
            MenuRow(icon: "moon", title: "Темная тема", action: {})
            MenuRow(icon: "globe", title: "Язык", action: {})
            Divider().padding(.vertical, 8)
            MenuRow(icon: "questionmark.circle", title: "Помощь", action: {})
            MenuRow(icon: "info.circle", title: "О приложении", action: {})
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Divider()
            
            HStack {
                Text("Sekretar v1.0")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Spacer()
                
                Text("Made with ♥️")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding()
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
