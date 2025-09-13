import SwiftUI

struct AIActionPreviewView: View {
    let action: AIAction
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Action Details
                    actionDetailsSection
                    
                    // Confidence Indicator
                    confidenceSection
                    
                    // Payload Preview
                    if !action.payload.isEmpty {
                        payloadSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("AI Action Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: action.type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(actionColor)
            }
            
            // Title
            Text(action.title)
                .font(DesignSystem.Typography.title1)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Action type badge
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                Text("AI Suggestion")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(DesignSystem.Colors.primaryBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.primaryBlue.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Action Details Section
    private var actionDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Action Details", systemImage: "info.circle")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(action.description)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .padding()
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
    
    // MARK: - Confidence Section
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Confidence Level", systemImage: "speedometer")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack {
                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * action.confidence, height: 8)
                            .cornerRadius(4)
                            .animation(.easeInOut(duration: 0.5), value: action.confidence)
                    }
                }
                .frame(height: 8)
                
                // Confidence percentage
                Text("\(Int(action.confidence * 100))%")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(confidenceColor)
                    .fontWeight(.semibold)
                    .frame(width: 40, alignment: .trailing)
            }
            
            // Confidence description
            Text(confidenceDescription)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Payload Section
    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Action Parameters", systemImage: "gearshape")
                .font(DesignSystem.Typography.cardTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(sortedPayloadKeys, id: \.self) { key in
                    PayloadRowView(key: key, value: action.payload[key])
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if action.requiresConfirmation {
                // Confirmation required
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(DesignSystem.Colors.priorityMedium)
                        Text("This action requires your confirmation")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.priorityMedium.opacity(0.1))
                    .cornerRadius(8)
                    
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Cancel button
                        Button(action: onCancel) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Cancel")
                            }
                            .font(DesignSystem.Typography.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.Colors.textTertiary.opacity(0.2))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        
                        // Confirm button
                        Button(action: onConfirm) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Confirm")
                            }
                            .font(DesignSystem.Typography.buttonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(actionColor)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                    }
                }
            } else {
                // Auto-execute notification
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(DesignSystem.Colors.completed)
                        Text("This action will execute automatically")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.completed.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button(action: onConfirm) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Execute Now")
                        }
                        .font(DesignSystem.Typography.buttonText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(actionColor)
                        .foregroundColor(.white)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var actionColor: Color {
        switch action.type {
        case .createTask, .createEvent:
            return DesignSystem.Colors.completed
        case .updateTask, .updateEvent:
            return DesignSystem.Colors.primaryBlue
        case .deleteTask, .deleteEvent:
            return DesignSystem.Colors.overdue
        case .suggestTimeSlots, .prioritizeTasks:
            return DesignSystem.Colors.primaryBlue
        case .requestClarification:
            return DesignSystem.Colors.priorityMedium
        case .showError:
            return DesignSystem.Colors.overdue
        }
    }
    
    private var confidenceColor: Color {
        switch action.confidence {
        case 0.8...1.0:
            return DesignSystem.Colors.completed
        case 0.6..<0.8:
            return DesignSystem.Colors.priorityMedium
        default:
            return DesignSystem.Colors.overdue
        }
    }
    
    private var confidenceDescription: String {
        switch action.confidence {
        case 0.9...1.0:
            return "Very confident - This action should work perfectly"
        case 0.8..<0.9:
            return "Confident - This action is likely to be correct"
        case 0.7..<0.8:
            return "Moderately confident - Please review the details"
        case 0.6..<0.7:
            return "Less confident - You may want to make adjustments"
        default:
            return "Low confidence - Please verify this action is correct"
        }
    }
    
    private var sortedPayloadKeys: [String] {
        action.payload.keys.sorted { key1, key2 in
            // Prioritize important keys
            let importantKeys = ["title", "priority", "notes", "due_date", "start_date", "end_date"]
            let index1 = importantKeys.firstIndex(of: key1) ?? importantKeys.count
            let index2 = importantKeys.firstIndex(of: key2) ?? importantKeys.count
            
            if index1 != index2 {
                return index1 < index2
            }
            return key1 < key2
        }
    }
}

// MARK: - Payload Row View
struct PayloadRowView: View {
    let key: String
    let value: Any?
    
    var body: some View {
        HStack(alignment: .top) {
            Text(displayKey)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            
            Text(displayValue)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var displayKey: String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private var displayValue: String {
        if let value = value {
            if let string = value as? String {
                return string.isEmpty ? "Empty" : string
            } else if let number = value as? NSNumber {
                return number.stringValue
            } else if let date = value as? Date {
                return date.formatted(date: .abbreviated, time: .shortened)
            } else if let bool = value as? Bool {
                return bool ? "Yes" : "No"
            } else if let array = value as? [Any] {
                return array.isEmpty ? "None" : "\(array.count) items"
            } else {
                return String(describing: value)
            }
        }
        return "None"
    }
}

#if DEBUG
struct AIActionPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        AIActionPreviewView(
            action: AIAction(
                type: .createTask,
                title: "Create New Task",
                description: "Create a task called 'Prepare presentation' with high priority",
                confidence: 0.85,
                requiresConfirmation: true,
                payload: [
                    "title": "Prepare presentation",
                    "priority": 3,
                    "notes": "Create slides for quarterly review meeting",
                    "category": "Work",
                    "estimated_duration": 7200
                ]
            ),
            onConfirm: {},
            onCancel: {}
        )
    }
}
#endif