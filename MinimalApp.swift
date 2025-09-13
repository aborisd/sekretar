import SwiftUI

@main
struct MinimalSekretarApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Text("📱 Sekretar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("M0 Complete - Ready for M1")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // Status Cards
                VStack(spacing: 16) {
                    StatusCard(
                        title: "M0 Status",
                        value: "100% Complete ✅",
                        color: .green
                    )
                    
                    StatusCard(
                        title: "Next Phase",
                        value: "M1 - Basic Functionality",
                        color: .blue
                    )
                    
                    StatusCard(
                        title: "Architecture",
                        value: "SwiftUI + Core Data + EventKit",
                        color: .purple
                    )
                }
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("🚀 Implemented Features:")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    FeatureItem(text: "✅ Project setup (Xcode + SwiftUI)")
                    FeatureItem(text: "✅ Core Data models (Task, Event, Project)")
                    FeatureItem(text: "✅ EventKit integration")
                    FeatureItem(text: "✅ Notification system")
                    FeatureItem(text: "✅ AI Intent Service foundation")
                    FeatureItem(text: "✅ UI navigation structure")
                }
                
                Spacer()
                
                Text("Ready to start M1 development! 🎉")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Sekretar Demo")
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeatureItem: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
            .padding(.leading, 8)
    }
}

#Preview {
    ContentView()
}
