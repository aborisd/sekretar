# AI Calendar & Tasks App - Production Development Plan
**Version 3.0 - From MVP to Production-Ready System**

---

## 📋 Document Overview

**Purpose**: This document outlines the transition path from a working MVP to a production-ready AI-powered calendar application with advanced multi-agent infrastructure.

**Assumptions**: 
- ✅ MVP already completed (M0-M3 from original BRD)
- ✅ Basic app functionality working (CRUD tasks/events, simple AI, offline storage)
- ✅ 100+ beta users testing the MVP
- ✅ Core Data models established
- ✅ Basic OpenRouter API integration functional

**What We're Building**: Transforming the MVP into a scalable, intelligent system with:
- Multi-agent AI architecture
- Contextual long-term memory
- Advanced temporal intelligence
- Production-grade infrastructure
- Premium UX polish

---

## 🎯 Transition Strategy: MVP → Production

### Current State (MVP Completed)
```
Your MVP has:
✅ iOS app with SwiftUI
✅ Basic task/event CRUD
✅ Simple AI intent parsing (keyword-based)
✅ OpenRouter API integration (Claude/GPT)
✅ Core Data local storage
✅ EventKit read-only integration
✅ Basic widgets
✅ Local notifications

What's missing:
❌ Contextual memory (RAG)
❌ Multi-agent system
❌ Smart LLM routing
❌ Backend infrastructure
❌ Advanced features (temporal intelligence, collaboration, etc.)
❌ Production-grade sync
❌ Analytics and monitoring
```

### Migration Path Overview

**Phase 1 (Weeks 1-8): Foundation Enhancement**
- Add vector memory system (on-device + cloud)
- Implement smart LLM router
- Set up basic backend infrastructure
- Migrate from simple intent parsing to contextual AI

**Phase 2 (Weeks 9-16): Multi-Agent System**
- Deploy backend with agent orchestration
- Implement specialized agents (Planner, Scheduler, Context, etc.)
- Enable advanced AI capabilities
- Add real-time sync with conflict resolution

**Phase 3 (Weeks 17-28): Advanced Features**
- Temporal intelligence (energy mapping, smart scheduling)
- Collaborative features (shared workspaces, dependencies)
- Lifelong memory (knowledge graph, semantic search)
- Smart integrations (email parsing, voice, Live Activities)

**Phase 4 (Weeks 29-36): Production Polish**
- Performance optimization
- Monetization implementation
- Localization & accessibility
- Launch preparation

---

## 📦 Pre-Migration Checklist

Before starting production development, ensure your MVP has:

### Code Quality
- [ ] Core Data schema is stable (with migration strategy)
- [ ] Repository pattern implemented cleanly
- [ ] No major technical debt
- [ ] Unit tests cover critical paths (>50%)
- [ ] Error handling in place

### Data Migration Strategy
```swift
// Add these fields to existing entities for backward compatibility
extension TaskEntity {
    // New fields for production features
    var embeddingVector: Data?  // For vector search
    var aiMetadata: String?     // JSON with AI-generated insights
    var serverSyncId: UUID?     // For backend sync
    var lastSyncedAt: Date?
    var conflictVersion: Int    // For conflict resolution
}

// Migration code
class DataMigrator {
    func migrateToProductionSchema() async throws {
        // 1. Add new columns without breaking existing data
        // 2. Generate embeddings for existing tasks (background)
        // 3. Set up sync IDs
        // 4. Preserve all user data
    }
}
```

### User Communication
- [ ] Inform beta users about upcoming changes
- [ ] Prepare changelog for major updates
- [ ] Set up feedback collection mechanism
- [ ] Plan for gradual feature rollout (feature flags)

### Infrastructure Preparation
- [ ] Backend hosting account ready (Railway/Fly.io/AWS)
- [ ] Database provisioned (PostgreSQL with pgvector)
- [ ] Redis instance for caching
- [ ] CI/CD pipeline configured
- [ ] Monitoring tools set up (Sentry, analytics)

---

## Phase 1: Foundation Enhancement (Weeks 1-8)

### Goal
Transform simple AI into contextual, memory-enabled system while maintaining backward compatibility with MVP.

---

### Week 1-2: Vector Memory System (On-Device)

**Objective**: Add semantic search capabilities to remember user interactions.

#### Tasks

**1. Integrate SQLite-VSS**
```swift
// Add to your existing database setup
class DatabaseManager {
    private let coreDataContainer: NSPersistentContainer
    private let vectorStore: VectorMemoryStore  // NEW
    
    init() {
        // Existing Core Data setup
        coreDataContainer = NSPersistentContainer(name: "AICalendar")
        
        // New: Vector store for embeddings
        vectorStore = try! VectorMemoryStore()
    }
}

// New file: VectorMemoryStore.swift
class VectorMemoryStore {
    private let db: Connection
    
    init() throws {
        let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vector_memory.db")
        
        db = try Connection(path.path)
        try db.loadExtension("vector0")  // sqlite-vss
        try setupSchema()
    }
    
    private func performSearch() {
        isSearching = true
        
        Task {
            do {
                results = try await LifelongMemory.shared.search(query)
            } catch {
                logger.error("Search failed: \(error)")
            }
            isSearching = false
        }
    }
}
```

**2. Auto-Retrospectives**
```python
# Backend: app/services/retrospective_generator.py
class RetrospectiveGenerator:
    """Generates periodic retrospectives"""
    
    async def generate_retrospective(
        self,
        user_id: str,
        period: str = "week"  # week, month, quarter
    ) -> Dict:
        """Generate comprehensive retrospective"""
        # Get time range
        if period == "week":
            start = datetime.now() - timedelta(days=7)
            title = "Weekly Retrospective"
        elif period == "month":
            start = datetime.now() - timedelta(days=30)
            title = "Monthly Retrospective"
        else:
            start = datetime.now() - timedelta(days=90)
            title = "Quarterly Retrospective"
        
        # Gather data
        data = await self._gather_data(user_id, start)
        
        # Generate with AI
        prompt = f"""
        Create a comprehensive retrospective for this user.
        
        Period: {period}
        Time range: {start.strftime('%b %d')} - {datetime.now().strftime('%b %d, %Y')}
        
        Data:
        - Tasks completed: {data['tasks_completed']}
        - Tasks created: {data['tasks_created']}
        - Completion rate: {data['completion_rate']:.0%}
        - Total work hours: {data['total_hours']}
        - Meetings: {data['meetings_count']}
        - Focus sessions: {data['focus_sessions']}
        - Most productive day: {data['best_day']}
        - Projects: {', '.join(data['active_projects'])}
        
        Key events:
        {self._format_key_events(data['key_events'])}
        
        Generate a retrospective with:
        
        ## 🎯 Highlights
        - 3-5 major accomplishments
        - Notable wins
        
        ## 📊 By the Numbers
        - Key statistics
        - Comparisons to previous period
        
        ## 🔍 Patterns Observed
        - Productivity patterns
        - Time management insights
        - Energy levels
        
        ## 💡 Lessons Learned
        - What worked well
        - What could be improved
        - Specific insights
        
        ## 🚀 Looking Forward
        - Recommendations for next {period}
        - Suggested focus areas
        - Goals to set
        
        Make it personal, specific, and actionable.
        Use markdown formatting.
        """
        
        llm = ChatAnthropic(model="claude-sonnet-4.5")
        response = await llm.ainvoke(prompt)
        
        return {
            "user_id": user_id,
            "period": period,
            "title": title,
            "content": response.content,
            "data_summary": data,
            "generated_at": datetime.now().isoformat()
        }
    
    async def _gather_data(self, user_id: str, start: datetime) -> Dict:
        """Gather retrospective data"""
        # Query database for user's activity
        async with get_db() as db:
            # Tasks
            tasks = await db.fetch(
                "SELECT * FROM tasks WHERE user_id = $1 AND created_at >= $2",
                user_id, start
            )
            
            completed_tasks = [t for t in tasks if t['completed_at']]
            
            # Events
            events = await db.fetch(
                "SELECT * FROM events WHERE user_id = $1 AND start_time >= $2",
                user_id, start
            )
            
            # Calculate metrics
            return {
                "tasks_created": len(tasks),
                "tasks_completed": len(completed_tasks),
                "completion_rate": len(completed_tasks) / len(tasks) if tasks else 0,
                "total_hours": sum(e['duration'] for e in events) / 3600,
                "meetings_count": len([e for e in events if e['type'] == 'meeting']),
                "focus_sessions": len([e for e in events if e['type'] == 'focus']),
                "best_day": self._find_most_productive_day(completed_tasks),
                "active_projects": list(set(t['project_id'] for t in tasks if t.get('project_id'))),
                "key_events": self._extract_key_events(events)
            }
```

**Deliverables Week 23-25**:
- ✅ Semantic search across all history
- ✅ Knowledge graph with entity relationships
- ✅ AI can answer questions about past
- ✅ Auto-generated retrospectives (weekly/monthly)
- ✅ Timeline visualization of memories

---

### Week 26-28: Smart Integrations

**Objective**: Integrate with external services for seamless workflows.

#### Tasks

**1. Email Parsing**
```python
# Backend: app/services/email_parser.py
class EmailParser:
    """Extracts tasks and events from emails"""
    
    async def parse_email(self, email: Dict) -> Dict:
        """Parse email for actionable items"""
        subject = email.get('subject', '')
        body = email.get('body', '')
        sender = email.get('from', {}).get('email', '')
        
        prompt = f"""
        Extract actionable items from this email.
        
        From: {sender}
        Subject: {subject}
        
        Body:
        {body[:2000]}  # Limit for token efficiency
        
        Identify:
        1. Tasks/action items (things to do)
        2. Meeting requests (with date/time)
        3. Deadlines (with dates)
        4. Important information to remember
        
        Return JSON:
        {{
            "tasks": [
                {{
                    "title": "Action item",
                    "notes": "Context from email",
                    "priority": "high|medium|low",
                    "due_date": "YYYY-MM-DD or null"
                }}
            ],
            "meetings": [
                {{
                    "title": "Meeting title",
                    "start_time": "ISO8601",
                    "duration_minutes": 60,
                    "attendees": ["email1", "email2"]
                }}
            ],
            "deadlines": [
                {{
                    "description": "What's due",
                    "due_date": "YYYY-MM-DD"
                }}
            ],
            "summary": "Brief summary of email"
        }}
        
        Only extract explicit action items, don't infer too much.
        Return ONLY JSON.
        """
        
        llm = ChatAnthropic(model="claude-sonnet-4.5")
        response = await llm.ainvoke(prompt)
        
        parsed = json.loads(response.content)
        
        # Add metadata
        parsed['email_id'] = email.get('id')
        parsed['sender'] = sender
        parsed['received_at'] = email.get('received_at')
        
        return parsed
    
    async def process_inbox(self, user_id: str) -> List[Dict]:
        """Process user's inbox for action items"""
        # Get unread emails from last 7 days
        emails = await self.fetch_recent_emails(user_id, days=7)
        
        parsed_items = []
        
        for email in emails:
            try:
                parsed = await self.parse_email(email)
                
                if parsed['tasks'] or parsed['meetings']:
                    parsed_items.append(parsed)
                    
                    # Auto-create items (with user confirmation)
                    await self.create_items_from_email(user_id, parsed)
                    
            except Exception as e:
                logger.error(f"Failed to parse email {email.get('id')}: {e}")
        
        return parsed_items
```

**2. Voice Memos to Tasks**
```swift
// Enhanced VoiceInputManager.swift
class VoiceInputManager {
    private let speechRecognizer: SFSpeechRecognizer
    private let aiService: AIService
    
    func processVoiceMemo(_ audioData: Data) async throws -> [Task] {
        // 1. Transcribe
        let transcript = try await transcribe(audioData)
        
        // 2. Structure with AI
        let structured = try await aiService.structureTranscript(transcript)
        
        // 3. Create tasks
        var tasks: [Task] = []
        for item in structured.items {
            let task = Task(
                title: item.title,
                notes: item.description,
                dueDate: item.dueDate,
                priority: item.priority
            )
            tasks.append(task)
        }
        
        return tasks
    }
    
    private func transcribe(_ audio: Data) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let recognizer = SFSpeechRecognizer() else {
                continuation.resume(throwing: VoiceError.recognizerUnavailable)
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: saveToTempFile(audio))
            
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

// AI Service extension
extension AIService {
    func structureTranscript(_ text: String) async throws -> StructuredOutput {
        let prompt = """
        Structure this voice memo into separate tasks.
        
        Transcript: "\(text)"
        
        Extract individual tasks/items. Common patterns:
        - "Remember to X"
        - "Need to Y"
        - "Don't forget Z"
        - "Buy A, B, and C"
        
        Return JSON:
        {
            "items": [
                {
                    "title": "Task title",
                    "description": "Additional context if any",
                    "due_date": "YYYY-MM-DD or null",
                    "priority": "high|medium|low"
                }
            ]
        }
        """
        
        let response = try await processIntent(prompt, user: currentUser)
        return try JSONDecoder().decode(StructuredOutput.self, from: response.payload)
    }
}
```

**3. Live Activities & Dynamic Island**
```swift
// New file: FocusSessionActivity.swift
import ActivityKit

struct FocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskName: String
        var elapsedTime: TimeInterval
        var totalDuration: TimeInterval
        var isRunning: Bool
    }
    
    var startTime: Date
    var taskId: UUID
}

class FocusSessionManager {
    private var currentActivity: Activity<FocusSessionAttributes>?
    
    func startFocusSession(task: Task, duration: TimeInterval) async throws {
        let attributes = FocusSessionAttributes(
            startTime: Date(),
            taskId: task.id
        )
        
        let initialState = FocusSessionAttributes.ContentState(
            taskName: task.title,
            elapsedTime: 0,
            totalDuration: duration,
            isRunning: true
        )
        
        currentActivity = try Activity<FocusSessionAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
        )
        
        // Start timer to update Live Activity
        startTimer()
    }
    
    func updateProgress(elapsedTime: TimeInterval) async {
        guard let activity = currentActivity else { return }
        
        let updatedState = FocusSessionAttributes.ContentState(
            taskName: activity.contentState.taskName,
            elapsedTime: elapsedTime,
            totalDuration: activity.contentState.totalDuration,
            isRunning: true
        )
        
        await activity.update(using: updatedState)
    }
    
    func endSession() async {
        guard let activity = currentActivity else { return }
        
        let finalState = FocusSessionAttributes.ContentState(
            taskName: activity.contentState.taskName,
            elapsedTime: activity.contentState.totalDuration,
            totalDuration: activity.contentState.totalDuration,
            isRunning: false
        )
        
        await activity.update(using: finalState)
        await activity.end(dismissalPolicy: .after(.now + 5))
    }
}

// Widget for Live Activity
struct FocusSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            // Lock screen UI
            HStack {
                VStack(alignment: .leading) {
                    Text(context.state.taskName)
                        .font(.headline)
                    
                    ProgressView(
                        value: context.state.elapsedTime,
                        total: context.state.totalDuration
                    )
                    
                    Text("\(formatTime(context.state.elapsedTime)) / \(formatTime(context.state.totalDuration))")
                        .font(.caption)
                }
                
                Spacer()
                
                if context.state.isRunning {
                    Image(systemName: "pause.circle.fill")
                        .font(.title)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
            .padding()
            
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.taskName)
                        .font(.headline)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedTime))
                        .font(.title2.monospacedDigit())
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: context.state.elapsedTime,
                        total: context.state.totalDuration
                    )
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(formatTime(context.state.elapsedTime))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
```

**Deliverables Week 26-28**:
- ✅ Email parsing extracts tasks/meetings
- ✅ Voice memos converted to structured tasks
- ✅ Live Activities for focus sessions
- ✅ Dynamic Island integration
- ✅ Calendar.app integration improvements

**Phase 3 Complete! 🎉**

Advanced features implemented:
- ✅ Temporal intelligence (energy mapping)
- ✅ Collaborative workspaces
- ✅ Lifelong memory & semantic search
- ✅ Smart integrations (email, voice, Live Activities)
- ✅ Auto-retrospectives

---

## Phase 4: Production Polish (Weeks 29-36)

### Goal
Prepare for App Store launch with premium quality.

---

### Week 29-31: Performance Optimization

**Objective**: Meet all performance budgets consistently.

#### Key Optimizations

**1. SwiftUI Performance**
```swift
// Optimized List rendering
struct TaskListView: View {
    @Query private var tasks: [TaskEntity]
    
    var body: some View {
        List {
            // Use LazyVStack for large lists
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedTasks.keys.sorted(), id: \.self) { date in
                    Section {
                        ForEach(groupedTasks[date] ?? []) { task in
                            TaskRow(task: task)
                                .id(task.id)  // Stable IDs for diffing
                        }
                    } header: {
                        DateHeader(date: date)
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            // Prefetch next batch
            prefetchTasks()
        }
    }
}

// Efficient image loading
struct AvatarView: View {
    let imageURL: URL?
    
    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "person.circle.fill")
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}
```

**2. Core Data Optimization**
```swift
// Batch operations
class TaskRepository {
    func batchCreate(_ tasks: [Task]) async throws {
        let context = modelContext
        
        // Batch insert
        context.performAndWait {
            for task in tasks {
                let entity = TaskEntity(from: task)
                context.insert(entity)
            }
        }
        
        try context.save()
    }
    
    // Prefetch relationships
    func fetchWithRelationships(limit: Int) async throws -> [Task] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.dueDate)],
            predicate: #Predicate { !$0.isDeleted }
        )
        
        // Prefetch project and subtasks
        descriptor.relationshipKeyPathsForPrefetching = [
            \.project,
            \.subtasks
        ]
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Task(from: $0) }
    }
}
```

**3. Network Optimization**
```swift
// Request batching
class NetworkOptimizer {
    private var pendingRequests: [APIRequest] = []
    private var batchTimer: Timer?
    
    func enqueue(_ request: APIRequest) {
        pendingRequests.append(request)
        
        // Batch requests within 100ms window
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.flushBatch()
        }
    }
    
    private func flushBatch() {
        guard !pendingRequests.isEmpty else { return }
        
        let batch = pendingRequests
        pendingRequests.removeAll()
        
        Task {
            // Send as single batched request
            try await backend.batch(batch)
        }
    }
}

// Image caching
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    func load(_ url: URL) async throws -> UIImage {
        let key = url.absoluteString as NSString
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageError.invalidData
        }
        
        cache.setObject(image, forKey: key)
        return image
    }
}
```

**Deliverables Week 29-31**:
- ✅ 60 FPS sustained on all screens
- ✅ App launch <500ms
- ✅ Memory usage <150MB typical
- ✅ Network bandwidth optimized
- ✅ Battery drain <5%/hour

---

### Week 32-34: Monetization & IAP

**Objective**: Implement subscription system and paywall.

#### Tasks

**1. StoreKit 2 Integration**
```swift
// Complete StoreManager.swift
@Observable
class StoreManager {
    var products: [Product] = []
    var purchasedSubscriptions: Set<Product> = []
    var subscriptionStatus: SubscriptionStatus?
    
    init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
            
            // Listen for transaction updates
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                "ai_calendar_basic_monthly",
                "ai_calendar_basic_yearly",
                "ai_calendar_pro_monthly",
                "ai_calendar_pro_yearly",
                "ai_calendar_premium_monthly",
                "ai_calendar_teams_monthly"
            ])
        } catch {
            logger.error("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update backend
            try await updateBackend(transaction: transaction)
            
            await transaction.finish()
            await updatePurchasedProducts()
            
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    private func updatePurchasedProducts() async {
        var purchased: Set<Product> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if let product = products.first(where: { $0.id == transaction.productID }) {
                purchased.insert(product)
            }
        }
        
        purchasedSubscriptions = purchased
        
        // Update subscription status
        await updateSubscriptionStatus()
    }
    
    private func updateSubscriptionStatus() async {
        guard let product = purchasedSubscriptions.first else {
            subscriptionStatus = nil
            return
        }
        
        guard let status = try? await product.subscription?.status.first else {
            return
        }
        
        subscriptionStatus = SubscriptionStatus(
            tier: tierFrom(productId: product.id),
            renewalDate: status.renewalInfo.expirationDate,
            isInGracePeriod: status.state == .inGracePeriod,
            willAutoRenew: status.renewalInfo.willAutoRenew
        )
    }
    
    private func updateBackend(transaction: Transaction) async throws {
        // Send receipt to backend for verification
        try await backend.verifyPurchase(
            transactionId: String(transaction.id),
            productId: transaction.productID
        )
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

struct SubscriptionStatus {
    let tier: SubscriptionTier
    let renewalDate: Date?
    let isInGracePeriod: Bool
    let willAutoRenew: Bool
}
```

**2. Paywall UI**
```swift
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Hero section
                VStack(spacing: Spacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Unlock Full Potential")
                        .font(.largeTitle.bold())
                    
                    Text("AI-powered productivity with unlimited features")
                        .font(.title3)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xxl)
                
                // Feature comparison
                FeatureComparisonTable()
                
                // Pricing tiers
                VStack(spacing: Spacing.md) {
                    ForEach(store.products) { product in
                        PricingCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id
                        )
                        .onTapGesture {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal)
                
                // CTA button
                Button {
                    purchase()
                } label: {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Start Free Trial")
                            .font(.headline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedProduct == nil || isPurchasing)
                
                // Fine print
                VStack(spacing: Spacing.xs) {
                    Text("7-day free trial, then \(selectedProduct?.displayPrice ?? "$9.99")/month")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                    
                    HStack(spacing: Spacing.sm) {
                        Button("Terms") { }
                        Text("•")
                        Button("Privacy") { }
                        Text("•")
                        Button("Restore") {
                            restorePurchases()
                        }
                    }
                    .font(.caption)
                }
                .padding(.bottom, Spacing.xl)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
    
    private func purchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        
        Task {
            do {
                _ = try await store.purchase(product)
                dismiss()
            } catch {
                // Show error
                logger.error("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
    
    private func restorePurchases() {
        Task {
            try await store.restorePurchases()
        }
    }
}

struct FeatureComparisonTable: View {
    let features = [
        ("Tasks", "50", "200", "Unlimited", "Unlimited"),
        ("AI Queries", "5/day", "20/day", "Unlimited", "Unlimited"),
        ("AI Model", "Basic", "Better", "Premium", "Premium"),
        ("Cloud Sync", "❌", "✅", "✅", "✅"),
        ("Team Workspace", "❌", "❌", "5 members", "Unlimited"),
        ("Analytics", "Basic", "Advanced", "Advanced", "Advanced"),
        ("Priority Support", "❌", "❌", "✅", "✅")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Feature")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .frame(width: 70)
                Text("Basic")
                    .frame(width: 70)
                Text("Pro")
                    .frame(width: 70)
                Text("Teams")
                    .frame(width: 70)
            }
            .font(.caption.weight(.semibold))
            .padding()
            .background(Color.backgroundSecondary)
            
            Divider()
            
            // Rows
            ForEach(features.indices, id: \.self) { index in
                let feature = features[index]
                HStack {
                    Text(feature.0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(feature.1)
                        .frame(width: 70)
                    Text(feature.2)
                        .frame(width: 70)
                    Text(feature.3)
                        .frame(width: 70)
                    Text(feature.4)
                        .frame(width: 70)
                }
                .font(.caption)
                .padding()
                
                if index < features.count - 1 {
                    Divider()
                }
            }
        }
        .background(Color.backgroundPrimary)
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal)
    }
}
```

**Deliverables Week 32-34**:
- ✅ StoreKit 2 fully integrated
- ✅ Beautiful paywall UI
- ✅ 7-day free trial working
- ✅ Restore purchases functional
- ✅ Backend receipt validation
- ✅ Feature gating implemented

---

### Week 35-36: Final Polish & Launch Prep

**Objective**: Final QA, App Store assets, and launch.

#### Tasks

**1. Localization (RU + EN)**
```swift
// String catalog setup
// en.lproj/Localizable.strings
"today_greeting" = "Good morning! You have %d tasks today.";
"task_created" = "Task created";
"ai_processing" = "AI is thinking...";

// ru.lproj/Localizable.strings
"today_greeting" = "Доброе утро! У вас %d задач сегодня.";
"task_created" = "Задача создана";
"ai_processing" = "ИИ думает...";

// Usage
Text("today_greeting", count: tasks.count)
```

**2. Accessibility Audit**
```swift
// VoiceOver labels
TaskRow(task: task)
    .accessibilityLabel("\(task.title), priority \(task.priority?.rawValue ?? "none"), due \(task.dueDate?.formatted() ?? "no date")")
    .accessibilityHint("Double tap to view details. Swipe right to complete.")
    .accessibilityAddTraits(task.isCompleted ? [.isSelected] : [])
    .accessibilityRemoveTraits(.isButton)

// Dynamic Type support - already handled by using .font(.body) etc.

// High contrast mode
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

// Adjust colors for high contrast
Color.taskHigh.opacity(differentiateWithoutColor ? 1.0 : 0.8)
```

**3. App Store Assets**
- Screenshots (6.7", 6.5", 5.5" - all required sizes)
- App Preview videos (30 seconds each, 3-5 videos)
- App Icon (all sizes)
- Description (optimized for ASO)
- Keywords research
- Privacy nutrition label

**4. Beta Testing (TestFlight)**
```
Week 35:
- Internal testing (team)
- External beta (100 testers)
- Collect feedback
- Fix critical bugs

Week 36:
- Final build
- App Store submission
- Marketing preparation
- Launch coordination
```

**Deliverables Week 35-36**:
- ✅ App fully localized (RU + EN)
- ✅ Accessibility perfect (VoiceOver, Dynamic Type)
- ✅ All App Store assets ready
- ✅ 100 beta testers onboarded
- ✅ App submitted to App Store
- ✅ Marketing site live
- ✅ Launch plan executed

---

## 🎊 Production Launch Complete!

After 36 weeks, you have:

### ✅ **Core Features**
- Multi-agent AI system
- Contextual memory (RAG)
- Temporal intelligence
- Offline-first architecture
- Real-time sync

### ✅ **Advanced Features**
- Energy mapping & smart scheduling
- Collaborative workspaces
- Lifelong memory & semantic search
- Smart integrations (email, voice, Live Activities)
- Auto-retrospectives

### ✅ **Production Quality**
- 60 FPS performance
- <500ms app launch
- StoreKit 2 subscriptions
- Localization (RU + EN)
- Full accessibility
- GDPR compliant

### ✅ **Infrastructure**
- Scalable backend (FastAPI)
- PostgreSQL + pgvector
- Multi-agent orchestration (LangGraph)
- Smart LLM routing (60-70% cost savings)
- Monitoring & analytics

---

## 📊 Expected Metrics at Launch

| Metric | Target | Rationale |
|--------|--------|-----------|
| **D1 Retention** | 40%+ | Strong onboarding |
| **D7 Retention** | 25%+ | Value delivered quickly |
| **Conversion Rate** | 5-10% | Premium features compelling |
| **NPS** | 50+ | Delightful experience |
| **Crash-Free Rate** | 99.5%+ | Thorough testing |

---

## 🚀 Post-Launch Roadmap (v2.0+)

**Next 6 months**:
1. Expand to iPad (multi-window UI)
2. Apple Watch app
3. Mac app (Catalyst or native)
4. Advanced calendar sharing
5. Custom AI agents (user-programmable)
6. Integration marketplace

**Next 12 months**:
1. Web dashboard
2. Android app
3. API for third-party integrations
4. Enterprise features (SSO, admin console)
5. AI model fine-tuning on user data
6. Predictive scheduling (full automation)

---

## 📝 Notes on Delegation

This plan is designed to be delegated to AI agents like Claude Code. Each week has:
- ✅ Clear objectives
- ✅ Specific tasks with code examples
- ✅ Deliverables with success criteria
- ✅ Dependencies clearly marked

**How to use this plan**:
1. Take one week at a time
2. Copy the tasks into your AI coding assistant
3. Provide context from previous weeks
4. Review and iterate on the output
5. Test thoroughly before moving to next week

---

**Document Version**: 3.0  
**Status**: Production-Ready Roadmap  
**Target**: Transform MVP to World-Class Product  
**Duration**: 36 weeks (9 months)  
**Confidence**: High ✅

---

Good luck with your journey to production! 🚀💪 setupSchema() throws {
        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS memories 
            USING vss0(
                embedding(768),      -- 768-dim vector
                content TEXT,        -- Original text
                type TEXT,           -- "interaction", "task", "event", "insight"
                metadata TEXT,       -- JSON with additional context
                timestamp INTEGER,
                user_context TEXT    -- Snapshot of user state when created
            )
        """)
        
        // Index for fast queries
        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_memories_type 
            ON memories(type, timestamp DESC)
        """)
    }
    
    // Core methods
    func addMemory(
        content: String,
        type: MemoryType,
        metadata: [String: Any] = [:]
    ) async throws {
        let embedding = try await LocalEmbedder.shared.embed(content)
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
        
        try db.run("""
            INSERT INTO memories (embedding, content, type, metadata, timestamp, user_context)
            VALUES (?, ?, ?, ?, ?, ?)
        """,
            embedding.toData(),
            content,
            type.rawValue,
            String(data: metadataJSON, encoding: .utf8)!,
            Int(Date().timeIntervalSince1970),
            getCurrentUserContext()
        )
    }
    
    func searchSimilar(
        query: String,
        limit: Int = 5,
        filters: [MemoryFilter] = []
    ) async throws -> [Memory] {
        let queryEmbedding = try await LocalEmbedder.shared.embed(query)
        
        var sql = """
            SELECT 
                content,
                type,
                metadata,
                timestamp,
                user_context,
                vss_distance(embedding, ?) as distance
            FROM memories
            WHERE vss_search(embedding, ?)
        """
        
        // Apply filters
        if !filters.isEmpty {
            sql += " AND " + filters.map { $0.sqlClause }.joined(separator: " AND ")
        }
        
        sql += " ORDER BY distance LIMIT ?"
        
        let results = try db.prepare(sql).run(
            queryEmbedding.toData(),
            queryEmbedding.toData(),
            limit
        )
        
        return results.map { Memory(from: $0) }
    }
}

enum MemoryType: String {
    case interaction  // User-AI chat messages
    case task        // Task descriptions and changes
    case event       // Event details
    case insight     // AI-generated insights
    case pattern     // Detected behavioral patterns
}
```

**2. Add CoreML Embeddings (On-Device)**
```swift
// Download Apple's Universal Sentence Encoder or similar
// https://huggingface.co/apple/mobilenet_v2_1.0_224

class LocalEmbedder {
    static let shared = LocalEmbedder()
    
    private let model: MLModel
    private let maxLength = 512  // Token limit
    
    private init() {
        // Load CoreML model
        guard let modelURL = Bundle.main.url(forResource: "SentenceEncoder", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: modelURL) else {
            fatalError("Failed to load embedding model")
        }
        self.model = model
    }
    
    func embed(_ text: String) async throws -> [Float] {
        // Tokenize
        let tokens = tokenize(text)
        
        // Prepare input
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for (i, token) in tokens.enumerated() {
            inputArray[i] = NSNumber(value: token)
        }
        
        // Run model
        let input = SentenceEncoderInput(tokens: inputArray)
        let output = try model.prediction(from: input)
        
        // Extract embedding
        guard let embedding = output.featureValue(for: "embedding")?.multiArrayValue else {
            throw EmbeddingError.invalidOutput
        }
        
        // Convert to Float array
        return (0..<embedding.count).map { Float(truncating: embedding[$0]) }
    }
    
    private func tokenize(_ text: String) -> [Int32] {
        // Simple word-level tokenization (use proper tokenizer in production)
        let words = text.lowercased().split(separator: " ")
        return words.prefix(maxLength).map { word in
            Int32(word.hashValue % 50000)  // Vocabulary size
        }
    }
}

extension Array where Element == Float {
    func toData() -> Data {
        return self.withUnsafeBytes { Data($0) }
    }
}
```

**3. Integrate Memory into Existing AI Service**
```swift
// Modify your existing AIService class
class AIService {
    private let openRouter: OpenRouterClient
    private let vectorStore: VectorMemoryStore  // NEW
    private let cache: RequestCache
    
    func processIntent(_ input: String) async throws -> Intent {
        // NEW: Search for relevant memories before calling LLM
        let relevantMemories = try await vectorStore.searchSimilar(
            query: input,
            limit: 5,
            filters: [.type(.interaction), .type(.task)]
        )
        
        // Build enhanced prompt with context
        let contextualPrompt = buildPromptWithMemory(
            userInput: input,
            memories: relevantMemories,
            recentTasks: await getRecentTasks(),
            upcomingEvents: await getUpcomingEvents()
        )
        
        // Call LLM with rich context
        let response = try await openRouter.complete(
            model: "anthropic/claude-sonnet-4.5",
            messages: contextualPrompt,
            responseFormat: .json
        )
        
        let intent = try JSONDecoder().decode(Intent.self, from: response)
        
        // NEW: Save interaction to memory
        try await vectorStore.addMemory(
            content: "User: \(input)\nAI Action: \(intent.action) - \(intent.payload)",
            type: .interaction,
            metadata: [
                "intent": intent.action,
                "confidence": intent.confidence,
                "timestamp": Date().iso8601String
            ]
        )
        
        return intent
    }
    
    private func buildPromptWithMemory(
        userInput: String,
        memories: [Memory],
        recentTasks: [Task],
        upcomingEvents: [Event]
    ) -> [[String: String]] {
        var systemPrompt = """
        You are an intelligent calendar assistant with memory of past interactions.
        
        Current Context:
        - Time: \(Date().formatted())
        - Active tasks: \(recentTasks.count)
        - Upcoming events: \(upcomingEvents.count)
        """
        
        // Add relevant memories
        if !memories.isEmpty {
            systemPrompt += "\n\nRelevant Past Interactions:\n"
            for (index, memory) in memories.enumerated() {
                systemPrompt += "\n\(index + 1). \(memory.content)"
                systemPrompt += "\n   (from \(memory.timestamp.formatted(.relative(presentation: .named))))"
            }
        }
        
        systemPrompt += """
        
        Use this context to provide more personalized and relevant responses.
        Always return valid JSON matching the intent schema.
        """
        
        return [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userInput]
        ]
    }
}
```

**Deliverables Week 1-2**:
- ✅ Vector memory system working on-device
- ✅ AI responses include relevant past context
- ✅ "Do it like last time" queries work
- ✅ No performance regression (<100ms overhead)

---

### Week 3-4: Smart LLM Router (Cost Optimization)

**Objective**: Reduce AI costs by 60-70% through intelligent model selection.

#### Tasks

**1. Complexity Classifier**
```swift
// New file: ComplexityClassifier.swift
class ComplexityClassifier {
    func classify(_ input: String) -> Complexity {
        let text = input.lowercased()
        
        // Simple patterns (cheap model: Gemini Flash)
        let simplePatterns = [
            "создай задачу", "create task",
            "удали", "delete",
            "измени", "change", "rename",
            "покажи", "show me",
            "отметь", "mark as",
            "список", "list"
        ]
        
        for pattern in simplePatterns {
            if text.contains(pattern) {
                return .simple
            }
        }
        
        // Complex patterns (expensive model: Claude)
        let complexPatterns = [
            "разбей на подзадачи", "break down",
            "проанализируй", "analyze",
            "оптимизируй", "optimize",
            "предложи стратегию", "suggest strategy",
            "что если", "what if",
            "сравни", "compare",
            "декомпозируй", "decompose"
        ]
        
        for pattern in complexPatterns {
            if text.contains(pattern) {
                return .complex
            }
        }
        
        // Medium complexity (default)
        return .medium
    }
}

enum Complexity {
    case simple   // CRUD, basic queries → Gemini Flash ($0.075/$0.30)
    case medium   // Scheduling, prioritization → GPT-4o-mini ($0.15/$0.60)
    case complex  // Planning, analysis → Claude Sonnet ($3/$15)
}
```

**2. Smart Router with Caching**
```swift
// New file: SmartLLMRouter.swift
class SmartLLMRouter {
    private let geminiFlash: GeminiClient
    private let gpt4oMini: OpenAIClient
    private let claudeSonnet: AnthropicClient
    private let cache: LLMCache
    private let classifier: ComplexityClassifier
    
    init() {
        self.geminiFlash = GeminiClient(apiKey: Config.geminiKey)
        self.gpt4oMini = OpenAIClient(apiKey: Config.openAIKey)
        self.claudeSonnet = AnthropicClient(apiKey: Config.anthropicKey)
        self.cache = LLMCache()
        self.classifier = ComplexityClassifier()
    }
    
    func route(_ request: AIRequest) async throws -> AIResponse {
        // 1. Check cache first
        let cacheKey = generateCacheKey(request)
        if let cached = await cache.get(cacheKey) {
            analytics.record("llm_cache_hit", properties: ["model": cached.model])
            return cached
        }
        
        // 2. Classify complexity
        let complexity = classifier.classify(request.input)
        
        // 3. Check user tier
        let userTier = request.user.subscriptionTier
        
        // 4. Select model based on complexity + tier
        let selectedModel = selectModel(complexity: complexity, userTier: userTier)
        
        // 5. Generate response
        let response = try await generateWithRetry(
            model: selectedModel,
            request: request,
            maxRetries: 2
        )
        
        // 6. Cache result
        await cache.set(cacheKey, response, ttl: cacheTTL(for: complexity))
        
        // 7. Record metrics
        analytics.record("llm_request", properties: [
            "complexity": complexity.rawValue,
            "model": selectedModel.name,
            "user_tier": userTier.rawValue,
            "cost_usd": response.estimatedCost,
            "latency_ms": response.latencyMs
        ])
        
        return response
    }
    
    private func selectModel(
        complexity: Complexity,
        userTier: SubscriptionTier
    ) -> LLMClient {
        switch (complexity, userTier) {
        case (.simple, _):
            return geminiFlash  // Always cheapest for simple
            
        case (.medium, .free), (.medium, .basic):
            return geminiFlash  // Use cheap model for free/basic users
            
        case (.medium, .pro), (.medium, .premium), (.medium, .teams):
            return gpt4oMini  // Better quality for paid users
            
        case (.complex, .free), (.complex, .basic):
            return gpt4oMini  // Fallback for non-pro users
            
        case (.complex, .pro), (.complex, .premium), (.complex, .teams):
            return claudeSonnet  // Premium model for complex + paid
        }
    }
    
    private func generateWithRetry(
        model: LLMClient,
        request: AIRequest,
        maxRetries: Int
    ) async throws -> AIResponse {
        for attempt in 0...maxRetries {
            do {
                let response = try await model.generate(
                    prompt: request.prompt,
                    temperature: 0.1,
                    maxTokens: 2000,
                    timeout: 30
                )
                return response
            } catch let error as RateLimitError {
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))  // Exponential backoff
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    // Try fallback model
                    if model === claudeSonnet {
                        return try await generateWithRetry(
                            model: gpt4oMini,
                            request: request,
                            maxRetries: 1
                        )
                    }
                    throw error
                }
            }
        }
        throw LLMError.maxRetriesExceeded
    }
    
    private func cacheTTL(for complexity: Complexity) -> TimeInterval {
        switch complexity {
        case .simple: return 3600    // 1 hour
        case .medium: return 1800    // 30 minutes
        case .complex: return 600    // 10 minutes
        }
    }
}

// Simple in-memory cache (use Redis in production)
actor LLMCache {
    private var storage: [String: (response: AIResponse, expiry: Date)] = [:]
    
    func get(_ key: String) -> AIResponse? {
        guard let cached = storage[key], cached.expiry > Date() else {
            storage.removeValue(forKey: key)
            return nil
        }
        return cached.response
    }
    
    func set(_ key: String, _ response: AIResponse, ttl: TimeInterval) {
        let expiry = Date().addingTimeInterval(ttl)
        storage[key] = (response, expiry)
    }
}
```

**3. Update Existing AIService to Use Router**
```swift
class AIService {
    private let router: SmartLLMRouter  // NEW: Replace direct OpenRouter client
    private let vectorStore: VectorMemoryStore
    
    func processIntent(_ input: String, user: User) async throws -> Intent {
        // Build request with context
        let memories = try await vectorStore.searchSimilar(query: input, limit: 5)
        let prompt = buildPromptWithMemory(input, memories: memories)
        
        let request = AIRequest(
            input: input,
            prompt: prompt,
            user: user
        )
        
        // Use router instead of direct API call
        let response = try await router.route(request)
        
        // Parse intent
        let intent = try JSONDecoder().decode(Intent.self, from: response.content)
        
        // Save to memory
        try await vectorStore.addMemory(
            content: "User: \(input)\nAI: \(intent.summary)",
            type: .interaction
        )
        
        return intent
    }
}
```

**Deliverables Week 3-4**:
- ✅ Smart router reduces costs by 60-70%
- ✅ 30%+ cache hit rate
- ✅ Free users get Gemini Flash (cheap)
- ✅ Pro users get Claude for complex queries
- ✅ No quality degradation for paid users

---

### Week 5-6: Backend Foundation

**Objective**: Set up scalable backend infrastructure for future agent system.

#### Tasks

**1. Backend Project Setup**
```bash
# Create new backend directory
mkdir backend
cd backend

# Initialize FastAPI project
poetry init
poetry add fastapi uvicorn sqlalchemy asyncpg redis langgraph anthropic openai

# Project structure
backend/
├── app/
│   ├── __init__.py
│   ├── main.py           # FastAPI app
│   ├── config.py         # Configuration
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth.py       # Authentication endpoints
│   │   ├── ai.py         # AI processing endpoints
│   │   └── sync.py       # Sync endpoints
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── task.py
│   │   └── memory.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   └── llm_router.py
│   └── db/
│       ├── __init__.py
│       └── database.py
├── tests/
├── docker-compose.yml
├── Dockerfile
└── pyproject.toml
```

**2. Database Schema (PostgreSQL + pgvector)**
```sql
-- Install pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    apple_id VARCHAR(255) UNIQUE,  -- For Apple Sign In
    tier VARCHAR(20) DEFAULT 'free',  -- free, basic, pro, premium, teams
    created_at TIMESTAMP DEFAULT NOW(),
    last_active_at TIMESTAMP,
    preferences JSONB DEFAULT '{}'::jsonb
);

-- Tasks table (server-side copy)
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    notes TEXT,
    due_date TIMESTAMP,
    priority VARCHAR(10),
    project_id UUID,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    modified_at TIMESTAMP DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT false,
    version INTEGER DEFAULT 1,  -- For conflict resolution
    
    -- Indexes
    INDEX idx_tasks_user (user_id, is_deleted, completed_at),
    INDEX idx_tasks_due (user_id, due_date) WHERE due_date IS NOT NULL
);

-- Memories table (for RAG)
CREATE TABLE memories (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    embedding vector(768),  -- pgvector for semantic search
    memory_type VARCHAR(50) NOT NULL,  -- interaction, task, event, insight, pattern
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_memories_user_type (user_id, memory_type, created_at DESC)
);

-- Vector similarity index (IVFFlat for performance)
CREATE INDEX memories_embedding_idx 
    ON memories 
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Sync operations queue
CREATE TABLE sync_queue (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation VARCHAR(20) NOT NULL,  -- create, update, delete
    entity_type VARCHAR(20) NOT NULL,  -- task, event, project
    entity_id UUID NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',  -- pending, processing, completed, failed
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    error TEXT,
    
    INDEX idx_sync_queue_user_status (user_id, status, created_at)
);

-- Agent logs (for monitoring and debugging)
CREATE TABLE agent_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    agent_type VARCHAR(50) NOT NULL,  -- orchestrator, planner, scheduler, etc.
    input JSONB NOT NULL,
    output JSONB,
    model_used VARCHAR(50),
    latency_ms INTEGER,
    cost_usd DECIMAL(10, 6),
    status VARCHAR(20),  -- success, error, timeout
    error TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    
    INDEX idx_agent_logs_user_time (user_id, created_at DESC),
    INDEX idx_agent_logs_agent_type (agent_type, created_at DESC)
);
```

**3. FastAPI Application**
```python
# app/main.py
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .api import auth, ai, sync
from .db.database import engine, init_db

app = FastAPI(
    title="AI Calendar Backend",
    version="1.0.0",
    docs_url="/api/docs"
)

# CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Startup event
@app.on_event("startup")
async def startup():
    await init_db()
    print("✅ Database initialized")

# Health check
@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}

# Include routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(ai.router, prefix="/api/v1/ai", tags=["ai"])
app.include_router(sync.router, prefix="/api/v1/sync", tags=["sync"])

# app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Database
    database_url: str
    redis_url: str
    
    # AI APIs
    anthropic_api_key: str
    openai_api_key: str
    google_api_key: str  # For Gemini
    
    # Authentication
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    
    # Feature flags
    enable_agent_system: bool = False  # Enable in Phase 2
    enable_voice: bool = False
    
    class Config:
        env_file = ".env"

settings = Settings()

# app/api/ai.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from ..services.auth_service import get_current_user
from ..services.llm_router import SmartLLMRouter
from ..models.user import User

router = APIRouter()
llm_router = SmartLLMRouter()

class AIRequest(BaseModel):
    input: str
    context: dict = {}

class AIResponse(BaseModel):
    action: str
    payload: dict
    confidence: float
    requires_confirmation: bool

@router.post("/process", response_model=AIResponse)
async def process_ai_request(
    request: AIRequest,
    current_user: User = Depends(get_current_user)
):
    """Main AI processing endpoint"""
    try:
        # Route request through smart LLM router
        response = await llm_router.route(
            user=current_user,
            input=request.input,
            context=request.context
        )
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/insights")
async def get_insights(
    period: str = "week",
    current_user: User = Depends(get_current_user)
):
    """Get AI-generated insights about productivity"""
    # TODO: Implement in Phase 3
    return {"message": "Coming soon"}
```

**4. Docker Compose for Local Development**
```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:pg15
    environment:
      POSTGRES_DB: ai_calendar
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
  
  backend:
    build: .
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+asyncpg://postgres:postgres@postgres:5432/ai_calendar
      REDIS_URL: redis://redis:6379
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      GOOGLE_API_KEY: ${GOOGLE_API_KEY}
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
  redis_data:
```

**5. Deploy to Railway (Production)**
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Add PostgreSQL
railway add postgresql

# Add Redis
railway add redis

# Set environment variables
railway variables set ANTHROPIC_API_KEY=xxx
railway variables set OPENAI_API_KEY=xxx
railway variables set JWT_SECRET=xxx

# Deploy
railway up

# Get URL
railway domain
# Output: https://your-app.railway.app
```

**Deliverables Week 5-6**:
- ✅ Backend deployed and accessible
- ✅ PostgreSQL with pgvector running
- ✅ Basic API endpoints working
- ✅ Authentication implemented
- ✅ iOS app can connect to backend

---

### Week 7-8: iOS Backend Integration

**Objective**: Connect iOS app to new backend while maintaining offline-first architecture.

#### Tasks

**1. Network Layer**
```swift
// New file: BackendService.swift
class BackendService {
    private let baseURL: URL
    private let session: URLSession
    private let auth: AuthManager
    
    init() {
        self.baseURL = URL(string: Config.backendURL)!
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        self.auth = AuthManager.shared
    }
    
    // AI Processing
    func processAIRequest(
        _ input: String,
        context: [String: Any] = [:]
    ) async throws -> AIResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/ai/process"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await auth.getAccessToken())", 
                         forHTTPHeaderField: "Authorization")
        
        let body = [
            "input": input,
            "context": context
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                // Token expired, refresh and retry
                try await auth.refreshToken()
                return try await processAIRequest(input, context: context)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(AIResponse.self, from: data)
    }
    
    // Sync tasks
    func syncTasks(_ tasks: [Task]) async throws -> SyncResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/sync/tasks"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await auth.getAccessToken())", 
                         forHTTPHeaderField: "Authorization")
        
        let body = try JSONEncoder().encode(tasks)
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.syncFailed
        }
        
        return try JSONDecoder().decode(SyncResult.self, from: data)
    }
}

// Authentication Manager
class AuthManager {
    static let shared = AuthManager()
    
    private var accessToken: String?
    private var refreshToken: String?
    
    func getAccessToken() async throws -> String {
        // Check if token exists and is valid
        if let token = accessToken, !isTokenExpired(token) {
            return token
        }
        
        // Try to refresh
        if let refresh = refreshToken {
            try await refreshToken(refresh)
            return accessToken!
        }
        
        // Need to login
        throw AuthError.notAuthenticated
    }
    
    func login(appleIDCredential: ASAuthorizationAppleIDCredential) async throws {
        // Exchange Apple ID token for backend JWT
        let backend = BackendService()
        let response = try await backend.loginWithApple(credential: appleIDCredential)
        
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        
        // Save to Keychain
        try saveToKeychain(accessToken: response.accessToken, 
                          refreshToken: response.refreshToken)
    }
}
```

**2. Offline Queue**
```swift
// New file: OfflineQueue.swift
actor OfflineQueue {
    private var queue: [SyncOperation] = []
    private let storage: URL
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storage = docs.appendingPathComponent("sync_queue.json")
        loadQueue()
    }
    
    func enqueue(_ operation: SyncOperation) {
        queue.append(operation)
        saveQueue()
    }
    
    func processQueue() async throws {
        guard !queue.isEmpty else { return }
        
        let backend = BackendService()
        var processedIndices: [Int] = []
        
        for (index, operation) in queue.enumerated() {
            do {
                try await process(operation, backend: backend)
                processedIndices.append(index)
            } catch {
                logger.error("Failed to process operation \(operation.id): \(error)")
                // Keep in queue for retry
            }
        }
        
        // Remove processed operations
        for index in processedIndices.reversed() {
            queue.remove(at: index)
        }
        
        saveQueue()
    }
    
    private func process(_ operation: SyncOperation, backend: BackendService) async throws {
        switch operation {
        case .createTask(let task):
            _ = try await backend.createTask(task)
            
        case .updateTask(let task):
            try await backend.updateTask(task)
            
        case .deleteTask(let id):
            try await backend.deleteTask(id)
            
        case .createEvent(let event):
            _ = try await backend.createEvent(event)
        }
    }
    
    private func loadQueue() {
        guard let data = try? Data(contentsOf: storage),
              let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) else {
            return
        }
        self.queue = operations
    }
    
    private func saveQueue() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        try? data.write(to: storage)
    }
}

enum SyncOperation: Codable {
    case createTask(Task)
    case updateTask(Task)
    case deleteTask(UUID)
    case createEvent(Event)
    
    var id: UUID {
        switch self {
        case .createTask(let task), .updateTask(let task):
            return task.id
        case .deleteTask(let id):
            return id
        case .createEvent(let event):
            return event.id
        }
    }
}
```

**3. Update AIService to Use Backend Conditionally**
```swift
class AIService {
    private let localRouter: SmartLLMRouter     // On-device router (Phase 1)
    private let backend: BackendService         // Backend (Phase 2+)
    private let vectorStore: VectorMemoryStore
    
    func processIntent(_ input: String, user: User) async throws -> Intent {
        // Check connectivity and user tier
        let useBackend = NetworkMonitor.shared.isConnected && shouldUseBackend(user)
        
        if useBackend {
            // Use backend for advanced features
            let context = try await buildContext(input)
            let response = try await backend.processAIRequest(input, context: context)
            
            // Save to local memory for offline access
            try await vectorStore.addMemory(
                content: "User: \(input)\nAI: \(response.summary)",
                type: .interaction
            )
            
            return response.intent
        } else {
            // Fallback to local processing
            return try await processLocally(input, user: user)
        }
    }
    
    private func shouldUseBackend(_ user: User) -> Bool {
        // Always use backend for Pro+ users (better AI)
        if user.tier >= .pro {
            return true
        }
        
        // Free users: use local for simple, backend for complex (if connected)
        return false
    }
    
    private func processLocally(_ input: String, user: User) async throws -> Intent {
        // Use local smart router (from Week 3-4)
        let memories = try await vectorStore.searchSimilar(query: input, limit: 5)
        let prompt = buildPromptWithMemory(input, memories: memories)
        
        let request = AIRequest(input: input, prompt: prompt, user: user)
        let response = try await localRouter.route(request)
        
        let intent = try JSONDecoder().decode(Intent.self, from: response.content)
        
        try await vectorStore.addMemory(
            content: "User: \(input)\nAI: \(intent.summary)",
            type: .interaction
        )
        
        return intent
    }
}
```

**4. Background Sync**
```swift
// New file: SyncManager.swift
class SyncManager {
    static let shared = SyncManager()
    
    private let queue = OfflineQueue()
    private let backend = BackendService()
    
    func syncAll() async throws {
        // 1. Process offline queue
        try await queue.processQueue()
        
        // 2. Upload local changes
        try await uploadLocalChanges()
        
        // 3. Download remote changes
        try await downloadRemoteChanges()
        
        // 4. Resolve conflicts
        try await resolveConflicts()
    }
    
    // Register background task
    func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.aicalendar.sync",
            using: nil
        ) { task in
            Task {
                do {
                    try await self.syncAll()
                    task.setTaskCompleted(success: true)
                } catch {
                    logger.error("Background sync failed: \(error)")
                    task.setTaskCompleted(success: false)
                }
            }
        }
    }
    
    // Schedule next sync
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.aicalendar.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)  // 30 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
}

// In AppDelegate or App struct
func application(_ application: UIApplication, 
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    SyncManager.shared.registerBackgroundSync()
    return true
}

func applicationDidEnterBackground(_ application: UIApplication) {
    SyncManager.shared.scheduleBackgroundSync()
}
```

**Deliverables Week 7-8**:
- ✅ iOS app connects to backend successfully
- ✅ Offline queue preserves changes when offline
- ✅ Background sync works (every 30min + on foreground)
- ✅ Seamless fallback to local AI when offline
- ✅ No data loss during sync

**Phase 1 Complete! 🎉**

At this point you have:
- ✅ Vector memory system (contextual AI)
- ✅ Smart LLM router (60-70% cost savings)
- ✅ Backend infrastructure ready
- ✅ Offline-first architecture maintained
- ✅ Foundation for multi-agent system

---

## Phase 2: Multi-Agent System (Weeks 9-16)

### Goal
Transform backend into intelligent multi-agent orchestrator for complex tasks.

---

### Week 9-10: Agent Architecture Setup

**Objective**: Implement base agent system with LangGraph orchestration.

#### Tasks

**1. Install LangGraph and Dependencies**
```bash
cd backend
poetry add langgraph langchain-anthropic langchain-openai langchain-google-genai
poetry add networkx  # For knowledge graph
```

**2. Base Agent Class**
```python
# app/agents/base_agent.py
from abc import ABC, abstractmethod
from typing import Dict, Any, List
from langchain_anthropic import ChatAnthropic
from langchain_openai import ChatOpenAI
from langchain_google_genai import ChatGoogleGenerativeAI

class Agent(ABC):
    """Base class for all specialized agents"""
    
    def __init__(self, name: str, llm_config: Dict[str, Any]):
        self.name = name
        self.llm = self._init_llm(llm_config)
        self.memory = []
        self.tools = []
    
    def _init_llm(self, config: Dict[str, Any]):
        """Initialize LLM based on config"""
        provider = config.get("provider", "anthropic")
        model = config.get("model", "claude-sonnet-4.5")
        
        if provider == "anthropic":
            return ChatAnthropic(model=model, temperature=0.1)
        elif provider == "openai":
            return ChatOpenAI(model=model, temperature=0.1)
        elif provider == "google":
            return ChatGoogleGenerativeAI(model=model, temperature=0.1)
        else:
            raise ValueError(f"Unknown provider: {provider}")
    
    @abstractmethod
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process agent-specific task"""
        pass
    
    async def call_llm(self, prompt: str) -> str:
        """Call LLM with agent's context"""
        messages = [
            {"role": "system", "content": self.get_system_prompt()},
            {"role": "user", "content": prompt}
        ]
        
        response = await self.llm.ainvoke(messages)
        
        # Log interaction
        self.memory.append({
            "prompt": prompt,
            "response": response.content,
            "timestamp": datetime.now()
        })
        
        return response.content
    
    @abstractmethod
    def get_system_prompt(self) -> str:
        """Get agent-specific system prompt"""
        pass
```

**3. Orchestrator Agent**
```python
# app/agents/orchestrator.py
from .base_agent import Agent
from typing import Dict, Any
import json

class OrchestratorAgent(Agent):
    """Routes requests to specialized agents"""
    
    def __init__(self):
        super().__init__(
            name="orchestrator",
            llm_config={"provider": "google", "model": "gemini-1.5-flash"}  # Fast & cheap
        )
        self.agents = {}
    
    def register_agent(self, agent_type: str, agent: Agent):
        """Register a specialized agent"""
        self.agents[agent_type] = agent
    
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Route request to appropriate agent(s)"""
        user_input = input_data.get("input", "")
        context = input_data.get("context", {})
        
        # Classify intent and determine agent
        classification = await self.classify_intent(user_input, context)
        
        # Route to appropriate agent
        agent_type = classification["primary_agent"]
        requires_multiple = classification["requires_multiple_agents"]
        
        if requires_multiple:
            # Multi-agent workflow (e.g., plan then schedule)
            return await self.orchestrate_multi_agent(
                user_input, 
                context, 
                classification["agent_sequence"]
            )
        else:
            # Single agent
            agent = self.agents.get(agent_type)
            if not agent:
                raise ValueError(f"Agent {agent_type} not registered")
            
            return await agent.process({
                "input": user_input,
                "context": context,
                "classification": classification
            })
    
    async def classify_intent(self, user_input: str, context: Dict) -> Dict[str, Any]:
        """Classify user intent and determine routing"""
        prompt = f"""
        Classify this user request for optimal agent routing.
        
        User input: "{user_input}"
        
        Context:
        - Active tasks: {context.get('active_tasks_count', 0)}
        - Upcoming events: {context.get('upcoming_events_count', 0)}
        - User tier: {context.get('user_tier', 'free')}
        
        Available agents:
        - planner: Long-term planning, task decomposition, goal setting
        - scheduler: Finding time slots, calendar optimization
        - context: Memory search, information retrieval
        - assistant: General chat, simple questions
        - analyst: Insights, pattern analysis, recommendations
        
        Return JSON:
        {{
            "category": "plan|schedule|query|chat|analyze",
            "primary_agent": "planner|scheduler|context|assistant|analyst",
            "confidence": 0.0-1.0,
            "requires_multiple_agents": true|false,
            "agent_sequence": ["agent1", "agent2"],  // if multiple
            "reasoning": "Brief explanation"
        }}
        
        Respond with ONLY valid JSON, no markdown.
        """
        
        response = await self.call_llm(prompt)
        
        # Extract JSON from response
        try:
            # Remove markdown code blocks if present
            json_str = response.strip()
            if json_str.startswith("```"):
                json_str = json_str.split("```")[1]
                if json_str.startswith("json"):
                    json_str = json_str[4:]
            
            return json.loads(json_str)
        except json.JSONDecodeError:
            # Fallback to assistant for ambiguous requests
            return {
                "category": "chat",
                "primary_agent": "assistant",
                "confidence": 0.5,
                "requires_multiple_agents": False,
                "reasoning": "Could not parse intent, defaulting to assistant"
            }
    
    async def orchestrate_multi_agent(
        self, 
        user_input: str, 
        context: Dict, 
        agent_sequence: List[str]
    ) -> Dict[str, Any]:
        """Coordinate multiple agents in sequence"""
        results = []
        accumulated_context = context.copy()
        
        for agent_type in agent_sequence:
            agent = self.agents.get(agent_type)
            if not agent:
                continue
            
            result = await agent.process({
                "input": user_input,
                "context": accumulated_context,
                "previous_results": results
            })
            
            results.append(result)
            accumulated_context.update(result.get("context_updates", {}))
        
        # Combine results
        return {
            "action": "multi_agent_complete",
            "results": results,
            "final_context": accumulated_context
        }
    
    def get_system_prompt(self) -> str:
        return """
        You are an orchestrator agent that routes user requests to specialized agents.
        Always respond with valid JSON following the specified schema.
        Be decisive and confident in your routing decisions.
        """
```

**4. Planner Agent**
```python
# app/agents/planner.py
from .base_agent import Agent
from typing import Dict, Any
import json

class PlannerAgent(Agent):
    """Handles complex task decomposition and planning"""
    
    def __init__(self):
        super().__init__(
            name="planner",
            llm_config={"provider": "anthropic", "model": "claude-sonnet-4.5"}  # Best reasoning
        )
    
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Break down complex goals into actionable subtasks"""
        user_input = input_data.get("input", "")
        context = input_data.get("context", {})
        
        prompt = f"""
        Create a detailed, actionable plan for this goal.
        
        User's goal: "{user_input}"
        
        Current context:
        - Active tasks: {context.get('active_tasks_count', 0)}
        - Available time this week: {context.get('free_hours', 'unknown')} hours
        - User patterns: {json.dumps(context.get('user_patterns', {}), indent=2)}
        - Workload: {context.get('workload_status', 'normal')}
        
        Create a plan with:
        1. **Subtasks**: Break down into 3-8 specific, actionable subtasks
           - Each subtask should be completable in one sitting
           - Include estimated duration (in minutes)
           - Assign priority (P0=critical, P1=high, P2=medium, P3=low)
        
        2. **Timeline**: Suggest when to work on each subtask
           - Consider user's available time
           - Account for dependencies
           - Be realistic about completion dates
        
        3. **Dependencies**: Identify which tasks must be done before others
        
        4. **Potential blockers**: Anticipate what could go wrong
        
        5. **Success criteria**: How to know when the goal is achieved
        
        Return JSON:
        {{
            "subtasks": [
                {{
                    "id": "unique_id",
                    "title": "Subtask title",
                    "description": "What needs to be done",
                    "estimated_duration_minutes": 60,
                    "priority": "P0|P1|P2|P3",
                    "suggested_date": "YYYY-MM-DD or relative like 'tomorrow'",
                    "dependencies": ["id_of_blocking_task"]
                }}
            ],
            "timeline": "Overall timeline summary (e.g., '2-3 weeks')",
            "total_estimated_hours": 10.5,
            "critical_path": ["task_id1", "task_id2"],
            "potential_blockers": ["What could delay this"],
            "success_criteria": ["How to measure success"],
            "recommendations": ["Additional suggestions"]
        }}
        
        Be specific, realistic, and actionable. Respond with ONLY valid JSON.
        """
        
        response = await self.call_llm(prompt)
        plan = self._parse_json(response)
        
        # Validate plan feasibility
        validation = await self._validate_plan(plan, context)
        
        if not validation["is_feasible"]:
            # Adjust plan
            plan = await self._adjust_plan(plan, validation["issues"])
        
        return {
            "action": "plan_created",
            "plan": plan,
            "validation": validation,
            "confidence": validation["confidence"]
        }
    
    async def _validate_plan(self, plan: Dict, context: Dict) -> Dict[str, Any]:
        """Validate if plan is realistic given user's constraints"""
        total_hours = plan.get("total_estimated_hours", 0)
        available_hours = context.get("free_hours", 40)  # Default 40h/week
        
        issues = []
        
        if total_hours > available_hours:
            issues.append(f"Plan requires {total_hours}h but only {available_hours}h available")
        
        # Check for circular dependencies
        deps = {}
        for task in plan.get("subtasks", []):
            deps[task["id"]] = task.get("dependencies", [])
        
        if self._has_circular_dependency(deps):
            issues.append("Circular dependencies detected in task graph")
        
        is_feasible = len(issues) == 0
        confidence = 0.9 if is_feasible else 0.6
        
        return {
            "is_feasible": is_feasible,
            "issues": issues,
            "confidence": confidence
        }
    
    async def _adjust_plan(self, plan: Dict, issues: List[str]) -> Dict[str, Any]:
        """Adjust plan to address feasibility issues"""
        prompt = f"""
        The following plan has feasibility issues. Adjust it to make it realistic.
        
        Original plan:
        {json.dumps(plan, indent=2)}
        
        Issues:
        {chr(10).join(f"- {issue}" for issue in issues)}
        
        Adjust the plan by:
        - Reducing scope if timeline is too tight
        - Breaking large tasks into smaller chunks
        - Removing circular dependencies
        - Suggesting what could be deferred
        
        Return the adjusted plan in the same JSON format.
        """
        
        response = await self.call_llm(prompt)
        return self._parse_json(response)
    
    def _has_circular_dependency(self, deps: Dict[str, List[str]]) -> bool:
        """Check for circular dependencies using DFS"""
        visited = set()
        rec_stack = set()
        
        def dfs(node):
            visited.add(node)
            rec_stack.add(node)
            
            for neighbor in deps.get(node, []):
                if neighbor not in visited:
                    if dfs(neighbor):
                        return True
                elif neighbor in rec_stack:
                    return True
            
            rec_stack.remove(node)
            return False
        
        for node in deps:
            if node not in visited:
                if dfs(node):
                    return True
        
        return False
    
    def _parse_json(self, response: str) -> Dict:
        """Safely parse JSON from LLM response"""
        try:
            json_str = response.strip()
            if json_str.startswith("```"):
                json_str = json_str.split("```")[1]
                if json_str.startswith("json"):
                    json_str = json_str[4:]
            return json.loads(json_str)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON: {e}")
            return {}
    
    def get_system_prompt(self) -> str:
        return """
        You are an expert planning agent specialized in breaking down complex goals.
        You create realistic, actionable plans with proper task decomposition.
        Always consider dependencies, time constraints, and potential blockers.
        Respond ONLY with valid JSON, no markdown or explanations outside the JSON.
        """
```

**5. Scheduler Agent**
```python
# app/agents/scheduler.py
from .base_agent import Agent
from typing import Dict, Any, List
from datetime import datetime, timedelta
import json

class SchedulerAgent(Agent):
    """Finds optimal time slots for tasks"""
    
    def __init__(self):
        super().__init__(
            name="scheduler",
            llm_config={"provider": "openai", "model": "gpt-4o-mini"}  # Good balance
        )
    
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Find and score optimal time slots"""
        task = input_data.get("task", {})
        calendar = input_data.get("calendar", [])
        context = input_data.get("context", {})
        
        # Find free slots
        free_slots = self._find_free_slots(
            calendar=calendar,
            duration=task.get("estimated_duration_minutes", 60),
            deadline=task.get("deadline"),
            start_date=datetime.now()
        )
        
        # Score slots with AI
        scored_slots = await self._score_slots(
            slots=free_slots,
            task=task,
            user_patterns=context.get("user_patterns", {})
        )
        
        return {
            "action": "time_slots_found",
            "slots": scored_slots[:3],  # Top 3
            "total_slots_found": len(free_slots),
            "confidence": 0.9
        }
    
    def _find_free_slots(
        self,
        calendar: List[Dict],
        duration: int,
        deadline: str = None,
        start_date: datetime = None
    ) -> List[Dict]:
        """Find free time slots in calendar"""
        if not start_date:
            start_date = datetime.now()
        
        if deadline:
            end_date = datetime.fromisoformat(deadline)
        else:
            end_date = start_date + timedelta(days=14)  # Default 2 weeks
        
        free_slots = []
        current = start_date.replace(hour=9, minute=0, second=0, microsecond=0)  # Start at 9am
        
        while current < end_date:
            # Skip weekends (optional, based on user prefs)
            if current.weekday() >= 5:
                current += timedelta(days=1)
                continue
            
            # Check if this slot is free
            slot_end = current + timedelta(minutes=duration)
            
            # Skip if outside work hours (9am-6pm default)
            if current.hour < 9 or slot_end.hour > 18:
                current += timedelta(minutes=30)
                continue
            
            # Check for conflicts with existing events
            has_conflict = False
            for event in calendar:
                event_start = datetime.fromisoformat(event["start_time"])
                event_end = datetime.fromisoformat(event["end_time"])
                
                if (current < event_end and slot_end > event_start):
                    has_conflict = True
                    break
            
            if not has_conflict:
                free_slots.append({
                    "start_time": current.isoformat(),
                    "end_time": slot_end.isoformat(),
                    "duration_minutes": duration,
                    "day_of_week": current.strftime("%A"),
                    "time_of_day": self._get_time_of_day(current)
                })
            
            # Move to next slot
            current += timedelta(minutes=30)
        
        return free_slots
    
    async def _score_slots(
        self,
        slots: List[Dict],
        task: Dict,
        user_patterns: Dict
    ) -> List[Dict]:
        """Use AI to score and rank time slots"""
        if not slots:
            return []
        
        prompt = f"""
        Rank these time slots for the task "{task.get('title', 'Untitled')}".
        
        Task details:
        - Duration: {task.get('estimated_duration_minutes', 60)} minutes
        - Priority: {task.get('priority', 'medium')}
        - Type: {task.get('type', 'general')}
        - Requires focus: {task.get('requires_focus', True)}
        
        Available slots:
        {json.dumps(slots[:20], indent=2)}  # Limit to 20 for token efficiency
        
        User patterns:
        - Peak productivity: {user_patterns.get('peak_hours', '9am-12pm')}
        - Prefers: {user_patterns.get('preferences', [])}
        - Avoids: {user_patterns.get('dislikes', [])}
        - Energy levels by time: {user_patterns.get('energy_by_time', {})}
        
        Score each slot 0-100 based on:
        1. Match with user's peak productivity time
        2. Day of week preference
        3. Proximity to deadline (if exists)
        4. Energy level match with task requirements
        5. Context switching (adjacent tasks)
        
        Return JSON array sorted by score (highest first):
        [
            {{
                "start_time": "ISO8601",
                "end_time": "ISO8601",
                "score": 95,
                "reasoning": "Brief explanation why this is good",
                "concerns": ["Potential issues if any"]
            }}
        ]
        
        Return ONLY JSON array, no markdown.
        """
        
        response = await self.call_llm(prompt)
        scored = self._parse_json_array(response)
        
        # Merge scores with original slot data
        for i, slot in enumerate(slots[:len(scored)]):
            slot.update(scored[i])
        
        return sorted(slots, key=lambda x: x.get("score", 0), reverse=True)
    
    def _get_time_of_day(self, dt: datetime) -> str:
        """Categorize time of day"""
        hour = dt.hour
        if 6 <= hour < 9:
            return "early_morning"
        elif 9 <= hour < 12:
            return "morning"
        elif 12 <= hour < 14:
            return "lunch"
        elif 14 <= hour < 17:
            return "afternoon"
        elif 17 <= hour < 20:
            return "evening"
        else:
            return "night"
    
    def _parse_json_array(self, response: str) -> List[Dict]:
        """Parse JSON array from LLM response"""
        try:
            json_str = response.strip()
            if json_str.startswith("```"):
                json_str = json_str.split("```")[1]
                if json_str.startswith("json"):
                    json_str = json_str[4:]
            return json.loads(json_str)
        except json.JSONDecodeError:
            return []
    
    def get_system_prompt(self) -> str:
        return """
        You are a scheduling optimization agent.
        Find and rank time slots based on user patterns and task requirements.
        Always consider energy levels, context switching, and user preferences.
        Respond ONLY with valid JSON.
        """
```

**6. LangGraph Workflow Integration**
```python
# app/agents/workflow.py
from langgraph.graph import StateGraph, END
from typing import TypedDict, List, Dict, Any
from .orchestrator import OrchestratorAgent
from .planner import PlannerAgent
from .scheduler import SchedulerAgent
from .context import ContextAgent
from .assistant import AssistantAgent

class AgentState(TypedDict):
    """Shared state across all agents"""
    user_id: str
    input: str
    context: Dict[str, Any]
    current_agent: str
    result: Dict[str, Any]
    history: List[Dict[str, Any]]
    errors: List[str]

class MultiAgentWorkflow:
    """Orchestrates multi-agent workflows using LangGraph"""
    
    def __init__(self):
        self.orchestrator = OrchestratorAgent()
        self.planner = PlannerAgent()
        self.scheduler = SchedulerAgent()
        self.context = ContextAgent()
        self.assistant = AssistantAgent()
        
        # Register agents
        self.orchestrator.register_agent("planner", self.planner)
        self.orchestrator.register_agent("scheduler", self.scheduler)
        self.orchestrator.register_agent("context", self.context)
        self.orchestrator.register_agent("assistant", self.assistant)
        
        # Build workflow graph
        self.graph = self._build_graph()
    
    def _build_graph(self) -> StateGraph:
        """Build LangGraph workflow"""
        workflow = StateGraph(AgentState)
        
        # Add nodes
        workflow.add_node("orchestrator", self._orchestrate)
        workflow.add_node("planner", self._plan)
        workflow.add_node("scheduler", self._schedule)
        workflow.add_node("context", self._get_context)
        workflow.add_node("assistant", self._assist)
        
        # Define entry point
        workflow.set_entry_point("orchestrator")
        
        # Conditional routing from orchestrator
        workflow.add_conditional_edges(
            "orchestrator",
            self._route_to_agent,
            {
                "plan": "planner",
                "schedule": "scheduler",
                "query": "context",
                "chat": "assistant",
                "done": END
            }
        )
        
        # Planner → Scheduler workflow (for complex planning)
        workflow.add_edge("planner", "scheduler")
        workflow.add_edge("scheduler", END)
        
        # Simple agents → END
        workflow.add_edge("context", END)
        workflow.add_edge("assistant", END)
        
        return workflow.compile()
    
    async def _orchestrate(self, state: AgentState) -> AgentState:
        """Orchestrator node"""
        result = await self.orchestrator.process({
            "input": state["input"],
            "context": state["context"]
        })
        
        state["result"] = result
        state["current_agent"] = result.get("primary_agent", "assistant")
        return state
    
    async def _plan(self, state: AgentState) -> AgentState:
        """Planner node"""
        result = await self.planner.process({
            "input": state["input"],
            "context": state["context"]
        })
        
        state["result"] = result
        state["history"].append({"agent": "planner", "result": result})
        return state
    
    async def _schedule(self, state: AgentState) -> AgentState:
        """Scheduler node"""
        # Get plan from previous step
        plan = state.get("result", {}).get("plan", {})
        
        # Schedule first subtask as example
        if plan.get("subtasks"):
            task = plan["subtasks"][0]
            result = await self.scheduler.process({
                "task": task,
                "calendar": state["context"].get("calendar", []),
                "context": state["context"]
            })
            
            state["result"]["scheduling"] = result
            state["history"].append({"agent": "scheduler", "result": result})
        
        return state
    
    async def _get_context(self, state: AgentState) -> AgentState:
        """Context node"""
        result = await self.context.process({
            "input": state["input"],
            "context": state["context"]
        })
        
        state["result"] = result
        return state
    
    async def _assist(self, state: AgentState) -> AgentState:
        """Assistant node"""
        result = await self.assistant.process({
            "input": state["input"],
            "context": state["context"]
        })
        
        state["result"] = result
        return state
    
    def _route_to_agent(self, state: AgentState) -> str:
        """Routing logic based on orchestrator's decision"""
        return state.get("current_agent", "assistant")
    
    async def run(self, user_id: str, user_input: str, context: Dict) -> Dict:
        """Execute workflow"""
        initial_state: AgentState = {
            "user_id": user_id,
            "input": user_input,
            "context": context,
            "current_agent": "",
            "result": {},
            "history": [],
            "errors": []
        }
        
        final_state = await self.graph.ainvoke(initial_state)
        return final_state["result"]
```

**7. Update Backend API to Use Agents**
```python
# app/api/ai.py (updated)
from fastapi import APIRouter, Depends, HTTPException
from ..agents.workflow import MultiAgentWorkflow
from ..services.auth_service import get_current_user
from ..models.user import User

router = APIRouter()
workflow = MultiAgentWorkflow()

@router.post("/process")
async def process_ai_request(
    request: AIRequest,
    current_user: User = Depends(get_current_user)
):
    """Process AI request through multi-agent system"""
    try:
        # Enrich context with user data
        context = {
            **request.context,
            "user_id": str(current_user.id),
            "user_tier": current_user.tier,
            "user_patterns": await get_user_patterns(current_user.id),
            "active_tasks_count": await count_active_tasks(current_user.id),
            "upcoming_events_count": await count_upcoming_events(current_user.id)
        }
        
        # Run through agent workflow
        result = await workflow.run(
            user_id=str(current_user.id),
            user_input=request.input,
            context=context
        )
        
        # Log for analytics
        await log_agent_interaction(
            user_id=current_user.id,
            input=request.input,
            result=result
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Agent processing failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

**Deliverables Week 9-10**:
- ✅ Base agent system implemented
- ✅ Orchestrator routes requests intelligently
- ✅ Planner agent creates detailed plans
- ✅ Scheduler agent finds optimal time slots
- ✅ LangGraph workflow orchestrates multi-agent tasks
- ✅ Backend API uses agent system

---

### Week 11-12: Context Agent & Memory Integration

**Objective**: Enable agents to access and use long-term memory.

#### Tasks

**1. Context Agent Implementation**
```python
# app/agents/context.py
from .base_agent import Agent
from typing import Dict, Any, List
from ..db.vector_store import VectorStore
from ..db.knowledge_graph import KnowledgeGraph

class ContextAgent(Agent):
    """Manages memory retrieval and context building"""
    
    def __init__(self):
        super().__init__(
            name="context",
            llm_config={"provider": "google", "model": "gemini-1.5-flash"}
        )
        self.vector_store = VectorStore()
        self.graph = KnowledgeGraph()
    
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Retrieve relevant context for query"""
        query = input_data.get("input", "")
        user_id = input_data.get("context", {}).get("user_id")
        
        # 1. Vector search for semantic similarity
        semantic_results = await self.vector_store.search(
            user_id=user_id,
            query=query,
            limit=5,
            memory_types=["interaction", "task", "event", "insight"]
        )
        
        # 2. Graph traversal for related entities
        entities = self._extract_entities(query)
        graph_results = await self.graph.find_related(
            user_id=user_id,
            entities=entities,
            max_depth=2
        )
        
        # 3. Synthesize context with LLM
        synthesized = await self._synthesize_context(
            query=query,
            semantic_results=semantic_results,
            graph_results=graph_results
        )
        
        return {
            "action": "context_retrieved",
            "semantic_matches": semantic_results,
            "related_entities": graph_results,
            "synthesized_context": synthesized,
            "confidence": 0.85
        }
    
    async def _synthesize_context(
        self,
        query: str,
        semantic_results: List[Dict],
        graph_results: List[Dict]
    ) -> str:
        """Use LLM to synthesize relevant context"""
        prompt = f"""
        The user asked: "{query}"
        
        Relevant past interactions:
        {self._format_memories(semantic_results)}
        
        Related information from knowledge graph:
        {self._format_graph_results(graph_results)}
        
        Synthesize this information into a concise context summary that would be helpful for answering the user's query.
        Focus on:
        - Patterns in past behavior
        - Relevant past decisions
        - Related tasks/events
        - Important context that would inform the answer
        
        Keep it brief (2-3 sentences max).
        """
        
        return await self.call_llm(prompt)
    
    def _extract_entities(self, text: str) -> List[str]:
        """Simple entity extraction (names, dates, projects)"""
        # This is simplified - use spaCy or similar in production
        words = text.split()
        entities = []
        
        # Detect capitalized words (potential names/projects)
        for word in words:
            if word[0].isupper() and len(word) > 2:
                entities.append(word)
        
        return entities
    
    def _format_memories(self, memories: List[Dict]) -> str:
        """Format memories for prompt"""
        if not memories:
            return "No relevant past interactions found."
        
        formatted = []
        for i, mem in enumerate(memories, 1):
            formatted.append(
                f"{i}. {mem['content']}\n"
                f"   (from {mem['created_at']}, relevance: {mem['similarity']:.2f})"
            )
        return "\n".join(formatted)
    
    def _format_graph_results(self, results: List[Dict]) -> str:
        """Format graph results for prompt"""
        if not results:
            return "No related entities found."
        
        formatted = []
        for result in results:
            formatted.append(
                f"- {result['entity_type']}: {result['name']}\n"
                f"  Relationship: {result['relationship']}"
            )
        return "\n".join(formatted)
    
    def get_system_prompt(self) -> str:
        return """
        You are a context retrieval agent specialized in finding and synthesizing relevant information.
        Provide concise, relevant context that helps answer user queries.
        Focus on patterns, relationships, and important historical context.
        """
```

**2. Vector Store Service**
```python
# app/db/vector_store.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pgvector.sqlalchemy import Vector
from ..models.memory import Memory
from typing import List, Dict, Any
import openai

class VectorStore:
    """PostgreSQL + pgvector storage for memories"""
    
    def __init__(self):
        self.embedder = openai.Embedding()
    
    async def add_memory(
        self,
        db: AsyncSession,
        user_id: str,
        content: str,
        memory_type: str,
        metadata: Dict = None
    ):
        """Store memory with embedding"""
        # Generate embedding
        embedding = await self._embed(content)
        
        # Create memory record
        memory = Memory(
            user_id=user_id,
            content=content,
            embedding=embedding,
            memory_type=memory_type,
            metadata=metadata or {}
        )
        
        db.add(memory)
        await db.commit()
    
    async def search(
        self,
        db: AsyncSession,
        user_id: str,
        query: str,
        limit: int = 5,
        memory_types: List[str] = None
    ) -> List[Dict[str, Any]]:
        """Semantic search for relevant memories"""
        # Generate query embedding
        query_embedding = await self._embed(query)
        
        # Build query
        stmt = select(
            Memory.content,
            Memory.memory_type,
            Memory.metadata,
            Memory.created_at,
            Memory.embedding.cosine_distance(query_embedding).label("distance")
        ).where(
            Memory.user_id == user_id
        )
        
        # Filter by type if specified
        if memory_types:
            stmt = stmt.where(Memory.memory_type.in_(memory_types))
        
        # Order by similarity and limit
        stmt = stmt.order_by("distance").limit(limit)
        
        # Execute
        result = await db.execute(stmt)
        rows = result.all()
        
        return [
            {
                "content": row.content,
                "memory_type": row.memory_type,
                "metadata": row.metadata,
                "created_at": row.created_at.isoformat(),
                "similarity": 1 - row.distance  # Convert distance to similarity
            }
            for row in rows
        ]
    
    async def _embed(self, text: str) -> List[float]:
        """Generate embedding vector"""
        response = await openai.Embedding.acreate(
            input=text,
            model="text-embedding-3-small"
        )
        return response['data'][0]['embedding']
```

**3. Knowledge Graph Service**
```python
# app/db/knowledge_graph.py
import networkx as nx
from typing import List, Dict, Any
import json

class KnowledgeGraph:
    """In-memory knowledge graph for entity relationships"""
    
    def __init__(self):
        self.graphs = {}  # user_id -> networkx graph
    
    async def add_entity(
        self,
        user_id: str,
        entity_id: str,
        entity_type: str,
        properties: Dict
    ):
        """Add or update entity in graph"""
        graph = self._get_graph(user_id)
        
        graph.add_node(
            entity_id,
            type=entity_type,
            **properties
        )
    
    async def add_relationship(
        self,
        user_id: str,
        from_id: str,
        to_id: str,
        rel_type: str,
        properties: Dict = None
    ):
        """Create relationship between entities"""
        graph = self._get_graph(user_id)
        
        graph.add_edge(
            from_id,
            to_id,
            type=rel_type,
            **(properties or {})
        )
    
    async def find_related(
        self,
        user_id: str,
        entities: List[str],
        max_depth: int = 2
    ) -> List[Dict[str, Any]]:
        """Find entities related to given entities"""
        graph = self._get_graph(user_id)
        related = []
        
        for entity in entities:
            # Find nodes matching entity name
            matching_nodes = [
                node for node, data in graph.nodes(data=True)
                if entity.lower() in data.get("name", "").lower()
            ]
            
            for node in matching_nodes:
                # BFS to find related nodes
                for neighbor in nx.single_source_shortest_path_length(
                    graph, node, cutoff=max_depth
                ).keys():
                    if neighbor != node:
                        node_data = graph.nodes[neighbor]
                        edge_data = graph.get_edge_data(node, neighbor)
                        
                        related.append({
                            "entity_id": neighbor,
                            "entity_type": node_data.get("type"),
                            "name": node_data.get("name"),
                            "relationship": edge_data.get("type") if edge_data else "related",
                            "depth": nx.shortest_path_length(graph, node, neighbor)
                        })
        
        return related
    
    def _get_graph(self, user_id: str) -> nx.DiGraph:
        """Get or create graph for user"""
        if user_id not in self.graphs:
            self.graphs[user_id] = nx.DiGraph()
        return self.graphs[user_id]
```

**4. Auto-populate Graph from User Data**
```python
# app/services/graph_builder.py
from ..db.knowledge_graph import KnowledgeGraph
from typing import List, Dict

class GraphBuilder:
    """Builds knowledge graph from user's tasks and events"""
    
    def __init__(self):
        self.graph = KnowledgeGraph()
    
    async def build_from_tasks(self, user_id: str, tasks: List[Dict]):
        """Add tasks to knowledge graph"""
        for task in tasks:
            # Add task entity
            await self.graph.add_entity(
                user_id=user_id,
                entity_id=str(task["id"]),
                entity_type="Task",
                properties={
                    "name": task["title"],
                    "priority": task.get("priority"),
                    "status": "active" if not task.get("completed_at") else "completed"
                }
            )
            
            # Link to project if exists
            if task.get("project_id"):
                await self.graph.add_relationship(
                    user_id=user_id,
                    from_id=str(task["id"]),
                    to_id=str(task["project_id"]),
                    rel_type="BELONGS_TO"
                )
            
            # Detect dependencies from description
            dependencies = self._extract_dependencies(task.get("notes", ""))
            for dep_id in dependencies:
                await self.graph.add_relationship(
                    user_id=user_id,
                    from_id=str(task["id"]),
                    to_id=dep_id,
                    rel_type="BLOCKS"
                )
    
    def _extract_dependencies(self, text: str) -> List[str]:
        """Extract task dependencies from text"""
        # Look for patterns like "after [task]" or "needs [task]"
        # Simplified implementation
        dependencies = []
        
        patterns = [
            r"after (\w+)",
            r"needs (\w+)",
            r"depends on (\w+)",
            r"blocked by (\w+)"
        ]
        
        import re
        for pattern in patterns:
            matches = re.findall(pattern, text.lower())
            dependencies.extend(matches)
        
        return dependencies
```

**Deliverables Week 11-12**:
- ✅ Context agent retrieves relevant memories
- ✅ Vector search working in PostgreSQL
- ✅ Knowledge graph tracks entity relationships
- ✅ Agents use context for better responses
- ✅ Auto-population of graph from user data

---

### Week 13-14: Assistant & Analyst Agents

**Objective**: Complete agent roster with conversational and analytical capabilities.

#### Tasks

**1. Assistant Agent (Conversational)**
```python
# app/agents/assistant.py
from .base_agent import Agent
from typing import Dict, Any

class AssistantAgent(Agent):
    """General conversational agent for simple queries and chat"""
    
    def __init__(self):
        super().__init__(
            name="assistant",
            llm_config={"provider": "anthropic", "model": "claude-sonnet-4.5"}
        )
    
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle general conversation and simple queries"""
        user_input = input_data.get("input", "")
        context = input_data.get("context", {})
        
        # Build contextual prompt
        prompt = f"""
        User says: "{user_input}"
        
        Current context:
        - Time: {context.get('current_time', 'unknown')}
        - Active tasks: {context.get('active_tasks_count', 0)}
        - Upcoming events: {context.get('upcoming_events_count', 0)}
        
        Relevant context from memory:
        {context.get('synthesized_context', 'No relevant history')}
        
        Respond naturally and helpfully. Keep it concise (2-3 sentences max).
        If the user is asking for action (create/update/delete), return JSON with action details.
        For general conversation, respond in natural language.
        """
        
        response = await self.call_llm(prompt)
        
        # Try to parse as JSON (if action requested)
        try:
            import json
            action = json.loads(response)
            return {
                "action": action.get("action", "chat"),
                "payload": action.get("payload", {}),
                "message": action.get("message", ""),
                "requires_confirmation": True
            }
        except json.JSONDecodeError:
            # Natural language response
            return {
                "action": "chat",
                "message": response,
                "requires_confirmation": False
            }
    
    def get_system_prompt(self) -> str:
        return """
        You are a friendly and helpful calendar assistant.
        Respond naturally to user queries.
        For action requests, return JSON with action details.
        For conversation, respond in natural language.
        Be concise, friendly, and proactive with suggestions.
        """
```

**2. Analyst Agent (Insights & Patterns)**
```python
# app/agents/analyst.py
from .base_agent import Agent
from typing import Dict, Any, List
from datetime import datetime, timedelta
import json

class AnalystAgent(Agent):
    """Generates insights and detects patterns in user behavior"""
    
    def __init__(self):
        super().__init__(
            name="analyst",
            llm_config={"provider": "anthropic", "model": "claude-sonnet-4.5"}
        )
    
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze user data and generate insights"""
        user_id = input_data.get("context", {}).get("user_id")
        period = input_data.get("period", "week")  # week, month, quarter
        
        # Gather data
        analytics_data = await self._gather_data(user_id, period)
        
        # Generate insights
        insights = await self._generate_insights(analytics_data)
        
        # Detect patterns
        patterns = await self._detect_patterns(analytics_data)
        
        # Recommendations
        recommendations = await self._generate_recommendations(
            insights,
            patterns,
            analytics_data
        )
        
        return {
            "action": "analysis_complete",
            "insights": insights,
            "patterns": patterns,
            "recommendations": recommendations,
            "data_summary": self._summarize_data(analytics_data),
            "confidence": 0.85
        }
    
    async def _gather_data(self, user_id: str, period: str) -> Dict[str, Any]:
        """Gather analytics data from database"""
        # This would query your database
        # Simplified for example
        return {
            "period": period,
            "tasks_created": 47,
            "tasks_completed": 38,
            "completion_rate": 0.81,
            "average_task_duration": 45,  # minutes
            "most_productive_day": "Tuesday",
            "least_productive_day": "Friday",
            "peak_hours": "9am-12pm",
            "total_work_hours": 32,
            "meetings_count": 12,
            "focus_sessions": 15,
            "task_distribution": {
                "high_priority": 12,
                "medium_priority": 23,
                "low_priority": 12
            },
            "completion_by_day": {
                "Monday": 8,
                "Tuesday": 9,
                "Wednesday": 7,
                "Thursday": 6,
                "Friday": 8
            }
        }
    
    async def _generate_insights(self, data: Dict) -> List[Dict[str, str]]:
        """Use LLM to generate key insights"""
        prompt = f"""
        Analyze this productivity data and provide 3-5 key insights.
        
        Data summary:
        - Tasks completed: {data['tasks_completed']}/{data['tasks_created']} ({data['completion_rate']:.0%})
        - Most productive day: {data['most_productive_day']}
        - Least productive day: {data['least_productive_day']}
        - Peak hours: {data['peak_hours']}
        - Average task duration: {data['average_task_duration']} minutes
        - Meetings: {data['meetings_count']}
        - Focus sessions: {data['focus_sessions']}
        
        Provide insights as JSON array:
        [
            {{
                "title": "Short insight title",
                "description": "Detailed explanation",
                "category": "productivity|patterns|recommendations",
                "impact": "high|medium|low"
            }}
        ]
        
        Focus on actionable insights about:
        - Productivity patterns
        - Time management effectiveness
        - Work-life balance
        - Opportunities for improvement
        
        Return ONLY JSON array.
        """
        
        response = await self.call_llm(prompt)
        return self._parse_json_array(response)
    
    async def _detect_patterns(self, data: Dict) -> List[Dict[str, str]]:
        """Detect behavioral patterns"""
        prompt = f"""
        Detect patterns in this user's behavior.
        
        Completion by day: {json.dumps(data['completion_by_day'])}
        Task distribution: {json.dumps(data['task_distribution'])}
        Meetings: {data['meetings_count']}
        Focus sessions: {data['focus_sessions']}
        
        Identify patterns like:
        - Procrastination tendencies
        - Energy level fluctuations
        - Task prioritization habits
        - Meeting vs. focus time balance
        
        Return JSON array:
        [
            {{
                "pattern": "Pattern name",
                "description": "What the pattern means",
                "frequency": "daily|weekly|occasional",
                "recommendation": "How to leverage or fix this"
            }}
        ]
        
        Return ONLY JSON array.
        """
        
        response = await self.call_llm(prompt)
        return self._parse_json_array(response)
    
    async def _generate_recommendations(
        self,
        insights: List[Dict],
        patterns: List[Dict],
        data: Dict
    ) -> List[Dict[str, str]]:
        """Generate actionable recommendations"""
        prompt = f"""
        Based on these insights and patterns, provide 3-5 actionable recommendations.
        
        Insights:
        {json.dumps(insights, indent=2)}
        
        Patterns:
        {json.dumps(patterns, indent=2)}
        
        Current stats:
        - Completion rate: {data['completion_rate']:.0%}
        - Average task duration: {data['average_task_duration']}min
        - Meetings: {data['meetings_count']} this {data['period']}
        
        Provide specific, actionable recommendations:
        [
            {{
                "title": "Recommendation title",
                "description": "What to do",
                "why": "Why this will help",
                "effort": "low|medium|high",
                "impact": "low|medium|high"
            }}
        ]
        
        Return ONLY JSON array.
        """
        
        response = await self.call_llm(prompt)
        return self._parse_json_array(response)
    
    def _summarize_data(self, data: Dict) -> Dict[str, Any]:
        """Create high-level summary"""
        return {
            "completion_rate": f"{data['completion_rate']:.0%}",
            "total_tasks": data['tasks_created'],
            "completed": data['tasks_completed'],
            "most_productive": data['most_productive_day'],
            "peak_hours": data['peak_hours']
        }
    
    def _parse_json_array(self, response: str) -> List[Dict]:
        """Parse JSON array from response"""
        try:
            json_str = response.strip()
            if json_str.startswith("```"):
                json_str = json_str.split("```")[1]
                if json_str.startswith("json"):
                    json_str = json_str[4:]
            return json.loads(json_str)
        except json.JSONDecodeError:
            return []
    
    def get_system_prompt(self) -> str:
        return """
        You are a productivity analyst agent.
        Analyze user behavior data to find patterns and generate insights.
        Provide specific, actionable recommendations for improvement.
        Always respond with valid JSON arrays.
        """
```

**3. Weekly Insights Scheduler**
```python
# app/services/insights_scheduler.py
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from ..agents.analyst import AnalystAgent
from ..db.database import get_db
from sqlalchemy import select
from ..models.user import User

class InsightsScheduler:
    """Automatically generate weekly insights for all users"""
    
    def __init__(self):
        self.scheduler = AsyncIOScheduler()
        self.analyst = AnalystAgent()
    
    def start(self):
        """Start scheduled jobs"""
        # Weekly insights every Monday at 6am
        self.scheduler.add_job(
            self.generate_weekly_insights,
            'cron',
            day_of_week='mon',
            hour=6,
            minute=0
        )
        
        self.scheduler.start()
    
    async def generate_weekly_insights(self):
        """Generate insights for all active users"""
        async for db in get_db():
            # Get active users (logged in within last 7 days)
            result = await db.execute(
                select(User).where(
                    User.last_active_at >= datetime.now() - timedelta(days=7)
                )
            )
            users = result.scalars().all()
            
            for user in users:
                try:
                    # Generate insights
                    result = await self.analyst.process({
                        "context": {"user_id": str(user.id)},
                        "period": "week"
                    })
                    
                    # Store insights
                    await self.store_insights(user.id, result)
                    
                    # Send notification (optional)
                    await self.notify_user(user, result)
                    
                except Exception as e:
                    logger.error(f"Failed to generate insights for user {user.id}: {e}")
    
    async def store_insights(self, user_id: str, insights: Dict):
        """Store insights in database"""
        # Save to memories table as "insight" type
        async for db in get_db():
            memory = Memory(
                user_id=user_id,
                content=json.dumps(insights),
                memory_type="insight",
                metadata={"period": "week", "generated_at": datetime.now().isoformat()}
            )
            db.add(memory)
            await db.commit()
```

**Deliverables Week 13-14**:
- ✅ Assistant agent handles general conversation
- ✅ Analyst agent generates weekly insights
- ✅ Automated insights generation every Monday
- ✅ All 5 agents integrated in workflow
- ✅ Complete multi-agent system functional

---

### Week 15-16: iOS Integration with Agents

**Objective**: Update iOS app to leverage full multi-agent capabilities.

#### Tasks

**1. Enhanced AIService with Agent Support**
```swift
// Update AIService.swift
class AIService {
    private let backend: BackendService
    private let localRouter: SmartLLMRouter
    private let vectorStore: VectorMemoryStore
    
    enum ProcessingMode {
        case local        // Use local router only
        case backend      // Use backend agents
        case hybrid       // Intelligently choose
    }
    
    func processIntent(
        _ input: String,
        user: User,
        mode: ProcessingMode = .hybrid
    ) async throws -> Intent {
        let processingMode = determineMode(mode, user: user)
        
        switch processingMode {
        case .local:
            return try await processLocally(input, user: user)
            
        case .backend:
            return try await processWithAgents(input, user: user)
            
        case .hybrid:
            // Use backend for complex, local for simple
            let complexity = ComplexityClassifier().classify(input)
            if complexity == .simple && NetworkMonitor.shared.isConnected == false {
                return try await processLocally(input, user: user)
            } else {
                return try await processWithAgents(input, user: user)
            }
        }
    }
    
    private func processWithAgents(_ input: String, user: User) async throws -> Intent {
        // Build rich context
        let context = try await buildContext(input, user: user)
        
        // Call backend agents
        let response = try await backend.processAIRequest(input, context: context)
        
        // Parse agent response
        let intent = Intent(from: response)
        
        // Save to local memory for offline access
        try await vectorStore.addMemory(
            content: "User: \(input)\nAgent: \(response.action) - \(response.summary)",
            type: .interaction,
            metadata: [
                "agent": response.agentUsed,
                "confidence": response.confidence
            ]
        )
        
        return intent
    }
    
    private func buildContext(_ input: String, user: User) async throws -> [String: Any] {
        // Gather all relevant context
        let recentTasks = try await taskRepository.fetchRecent(limit: 10)
        let upcomingEvents = try await eventRepository.fetchUpcoming(days: 7)
        let userPatterns = try await getUserPatterns(user)
        let calendar = try await eventRepository.fetchAll(
            from: Date(),
            to: Date().addingTimeInterval(14 * 86400)
        )
        
        return [
            "current_time": Date().iso8601String,
            "user_tier": user.subscriptionTier.rawValue,
            "active_tasks_count": recentTasks.filter { !$0.isCompleted }.count,
            "upcoming_events_count": upcomingEvents.count,
            "user_patterns": userPatterns.toDictionary(),
            "calendar": calendar.map { $0.toDictionary() },
            "free_hours": calculateFreeHours(calendar: calendar),
            "workload_status": assessWorkload(tasks: recentTasks)
        ]
    }
}
```

**2. Agent-Specific UI**
```swift
// New file: AgentResponseView.swift
struct AgentResponseView: View {
    let response: AgentResponse
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Agent indicator
            HStack {
                Image(systemName: response.agentIcon)
                    .foregroundColor(response.agentColor)
                Text(response.agentName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                // Confidence indicator
                ConfidenceBadge(confidence: response.confidence)
            }
            
            // Response content
            switch response.action {
            case .planCreated(let plan):
                PlanView(plan: plan)
            
            case .timeSlotsFound(let slots):
                TimeSlotsView(slots: slots)
            
            case .insightsGenerated(let insights):
                InsightsView(insights: insights)
            
            case .chat(let message):
                Text(message)
                    .font(.body)
            }
            
            // Multi-agent workflow indicator
            if let workflow = response.workflow {
                MultiAgentWorkflowView(workflow: workflow)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(CornerRadius.large)
    }
}

// Plan visualization
struct PlanView: View {
    let plan: Plan
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("📋 Plan Created")
                .font(.headline)
            
            Text(plan.timeline)
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            ForEach(plan.subtasks) { subtask in
                SubtaskRow(subtask: subtask)
            }
            
            if !plan.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("💡 Recommendations")
                        .font(.caption.weight(.semibold))
                    
                    ForEach(plan.recommendations, id: \.self) { rec in
                        Text("• \(rec)")
                            .font(.caption)
                    }
                }
                .padding(.top, Spacing.sm)
            }
        }
    }
}

// Time slots visualization
struct TimeSlotsView: View {
    let slots: [TimeSlot]
    @State private var selectedSlot: TimeSlot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("⏰ Suggested Time Slots")
                .font(.headline)
            
            ForEach(slots.prefix(3)) { slot in
                TimeSlotCard(
                    slot: slot,
                    isSelected: selectedSlot?.id == slot.id
                )
                .onTapGesture {
                    selectedSlot = slot
                }
            }
            
            if let selected = selectedSlot {
                Button("Schedule at \(selected.startTime.formatted(date: .omitted, time: .shortened))") {
                    scheduleTask(at: selected)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// Insights visualization
struct InsightsView: View {
    let insights: Insights
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("📊 Your Insights")
                .font(.headline)
            
            // Summary stats
            HStack(spacing: Spacing.lg) {
                StatCard(
                    title: "Completion Rate",
                    value: insights.completionRate,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Tasks Done",
                    value: "\(insights.tasksCompleted)",
                    icon: "list.bullet",
                    color: .blue
                )
            }
            
            // Key insights
            ForEach(insights.keyInsights) { insight in
                InsightCard(insight: insight)
            }
            
            // Patterns
            if !insights.patterns.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("🔍 Patterns Detected")
                        .font(.caption.weight(.semibold))
                    
                    ForEach(insights.patterns) { pattern in
                        PatternRow(pattern: pattern)
                    }
                }
            }
            
            // Recommendations
            if !insights.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("💡 Recommendations")
                        .font(.caption.weight(.semibold))
                    
                    ForEach(insights.recommendations) { rec in
                        RecommendationRow(recommendation: rec)
                    }
                }
            }
        }
    }
}
```

**Deliverables Week 15-16**:
- ✅ iOS app uses backend agents when online
- ✅ Agent-specific UI components
- ✅ Rich visualizations for plans/insights
- ✅ Seamless fallback to local processing
- ✅ Multi-agent workflows visible to user

**Phase 2 Complete! 🎉**

At this point you have:
- ✅ Full multi-agent system (5 specialized agents)
- ✅ LangGraph orchestration
- ✅ Context agent with memory retrieval
- ✅ Automated weekly insights
- ✅ iOS integration with agents
- ✅ Production-grade backend infrastructure

---

## Phase 3: Advanced Features (Weeks 17-28)

### Goal
Implement killer features that differentiate from competitors.

---

### Week 17-19: Temporal Intelligence

**Objective**: Enable AI to understand and optimize around user's energy patterns.

#### Tasks

**1. Energy Tracker**
```swift
// New file: EnergyTracker.swift
class EnergyTracker {
    private let storage: URL
    private var readings: [EnergyReading] = []
    
    struct EnergyReading: Codable {
        let timestamp: Date
        let activityType: ActivityType
        let duration: TimeInterval
        let focusQuality: FocusQuality  // How well user focused
        let energyLevel: EnergyLevel     // Self-reported or inferred
    }
    
    enum ActivityType: String, Codable {
        case deepWork
        case meeting
        case admin
        case break
    }
    
    enum FocusQuality: Int, Codable {
        case poor = 1
        case fair = 2
        case good = 3
        case excellent = 4
    }
    
    enum EnergyLevel: String, Codable {
        case peak      // Best performance
        case high      // Good performance
        case medium    // Average
        case low       // Struggling
    }
    
    func recordActivity(
        type: ActivityType,
        duration: TimeInterval,
        focusQuality: FocusQuality? = nil
    ) {
        let reading = EnergyReading(
            timestamp: Date(),
            activityType: type,
            duration: duration,
            focusQuality: focusQuality ?? inferFocusQuality(type, duration),
            energyLevel: inferEnergyLevel(type, focusQuality)
        )
        
        readings.append(reading)
        saveReadings()
        
        // Update patterns
        Task {
            await updatePatterns()
        }
    }
    
    func predictEnergyLevel(at date: Date) -> EnergyLevel {
        // Analyze historical data for this time
        let hourOfDay = Calendar.current.component(.hour, from: date)
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        
        let similarReadings = readings.filter {
            let readingHour = Calendar.current.component(.hour, from: $0.timestamp)
            let readingDay = Calendar.current.component(.weekday, from: $0.timestamp)
            return readingHour == hourOfDay && readingDay == dayOfWeek
        }
        
        if similarReadings.isEmpty {
            return .medium  // Default
        }
        
        // Calculate average energy level
        let avgEnergy = similarReadings
            .map { energyToScore($0.energyLevel) }
            .reduce(0, +) / Double(similarReadings.count)
        
        return scoreToEnergy(avgEnergy)
    }
    
    func suggestDeepWorkSlots(
        forDate date: Date,
        duration: TimeInterval
    ) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        var current = date.startOfDay.addingTimeInterval(9 * 3600)  // Start at 9am
        let end = date.startOfDay.addingTimeInterval(18 * 3600)     // End at 6pm
        
        while current < end {
            let slotEnd = current.addingTimeInterval(duration)
            
            // Check energy prediction
            let energyLevel = predictEnergyLevel(at: current)
            
            if energyLevel == .peak || energyLevel == .high {
                slots.append(TimeSlot(
                    start: current,
                    end: slotEnd,
                    energyLevel: energyLevel,
                    score: energyToScore(energyLevel)
                ))
            }
            
            current = current.addingTimeInterval(1800)  // Move by 30min
        }
        
        return slots.sorted { $0.score > $1.score }
    }
    
    private func inferFocusQuality(_ type: ActivityType, _ duration: TimeInterval) -> FocusQuality {
        // Infer from activity type and duration
        switch type {
        case .deepWork:
            return duration > 3600 ? .excellent : .good
        case .meeting:
            return .fair
        case .admin:
            return .good
        case .break:
            return .poor
        }
    }
    
    private func inferEnergyLevel(_ type: ActivityType, _ focus: FocusQuality?) -> EnergyLevel {
        // Combine activity type and focus quality to infer energy
        guard let focus = focus else { return .medium }
        
        switch (type, focus) {
        case (.deepWork, .excellent), (.deepWork, .good):
            return .peak
        case (.meeting, .good), (.admin, .excellent):
            return .high
        case (_, .fair):
            return .medium
        default:
            return .low
        }
    }
}
```

**2. Smart Scheduling with Energy Awareness**
```python
# Backend: app/agents/scheduler.py (enhanced)
class SchedulerAgent(Agent):
    # ... existing code ...
    
    async def _score_slots_with_energy(
        self,
        slots: List[Dict],
        task: Dict,
        user_patterns: Dict
    ) -> List[Dict]:
        """Enhanced scoring with energy levels"""
        energy_map = user_patterns.get('energy_by_time', {})
        
        for slot in slots:
            hour = datetime.fromisoformat(slot['start_time']).hour
            
            # Get predicted energy level
            energy_key = f"{slot['day_of_week']}_{hour}"
            energy_level = energy_map.get(energy_key, 'medium')
            
            # Base score from previous logic
            base_score = slot.get('score', 50)
            
            # Adjust based on task requirements vs energy level
            task_requires_focus = task.get('requires_focus', True)
            task_priority = task.get('priority', 'medium')
            
            energy_multiplier = {
                'peak': 1.5 if task_requires_focus else 1.2,
                'high': 1.3 if task_requires_focus else 1.1,
                'medium': 1.0,
                'low': 0.7 if task_requires_focus else 0.9
            }.get(energy_level, 1.0)
            
            priority_bonus = {
                'P0': 20,
                'P1': 10,
                'P2': 0,
                'P3': -10
            }.get(task_priority, 0)
            
            final_score = (base_score * energy_multiplier) + priority_bonus
            
            slot['score'] = min(100, final_score)
            slot['energy_level'] = energy_level
            slot['reasoning'] += f" Energy level: {energy_level}."
        
        return sorted(slots, key=lambda x: x['score'], reverse=True)
```

**3. Buffer Zone Automation**
```swift
// New file: BufferZoneManager.swift
class BufferZoneManager {
    func addBufferZones(to event: Event) async throws -> [Event] {
        var bufferEvents: [Event] = []
        
        // Pre-meeting prep time
        if event.type == .meeting {
            let prepDuration = calculatePrepDuration(event)
            let prepEvent = Event(
                title: "Prep: \(event.title)",
                startDate: event.startDate.addingTimeInterval(-prepDuration),
                endDate: event.startDate,
                type: .buffer,
                color: .orange
            )
            bufferEvents.append(prepEvent)
        }
        
        // Travel time
        if let location = event.location, location != "Home" && location != "Office" {
            let travelTime = try await calculateTravelTime(to: location)
            let travelEvent = Event(
                title: "Travel to \(event.title)",
                startDate: event.startDate.addingTimeInterval(-travelTime - prepDuration),
                endDate: event.startDate.addingTimeInterval(-prepDuration),
                type: .buffer,
                color: .blue
            )
            bufferEvents.append(travelEvent)
        }
        
        // Recovery time (after intense events)
        if event.duration > 2 * 3600 || event.isIntense {  // 2+ hour meetings
            let recoveryEvent = Event(
                title: "Recovery",
                startDate: event.endDate,
                endDate: event.endDate.addingTimeInterval(600),  // 10 min
                type: .buffer,
                color: .green
            )
            bufferEvents.append(recoveryEvent)
        }
        
        return bufferEvents
    }
    
    private func calculatePrepDuration(_ event: Event) -> TimeInterval {
        // 5-15 minutes based on meeting type
        if event.title.lowercased().contains("interview") ||
           event.title.lowercased().contains("presentation") {
            return 900  // 15 minutes
        }
        return 300  // 5 minutes
    }
    
    private func calculateTravelTime(to location: String) async throws -> TimeInterval {
        // Use Apple Maps or Google Maps API
        let directions = try await MKDirections.calculate(to: location)
        return directions.expectedTravelTime
    }
}
```

**Deliverables Week 17-19**:
- ✅ Energy tracking system implemented
- ✅ AI predicts user's energy levels by time
- ✅ Smart scheduling considers energy
- ✅ Auto-generated buffer zones for events
- ✅ Deep work slots suggested at peak times

---

### Week 20-22: Collaborative Features

**Objective**: Enable team collaboration with AI assistance.

#### Tasks

**1. Shared Workspaces**
```swift
// New file: Workspace.swift
@Model
class WorkspaceEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var ownerId: UUID
    
    @Relationship(deleteRule: .cascade) var members: [WorkspaceMember]
    @Relationship(deleteRule: .cascade) var projects: [ProjectEntity]
    @Relationship(deleteRule: .nullify) var sharedTasks: [TaskEntity]
}

@Model
class WorkspaceMember {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var email: String
    var role: String  // owner, admin, member
    var joinedAt: Date
    
    @Relationship(deleteRule: .nullify) var workspace: WorkspaceEntity?
}

class WorkspaceService {
    func createWorkspace(name: String, owner: User) async throws -> Workspace {
        let workspace = Workspace(
            name: name,
            ownerId: owner.id
        )
        
        // Create on backend
        let created = try await backend.createWorkspace(workspace)
        
        // Save locally
        try await repository.save(created)
        
        return created
    }
    
    func inviteMember(email: String, to workspace: Workspace) async throws {
        try await backend.inviteToWorkspace(
            workspaceId: workspace.id,
            email: email,
            role: .member
        )
        
        // Send notification
        await notificationService.send(
            to: email,
            type: .workspaceInvite,
            data: ["workspace": workspace.name]
        )
    }
    
    func syncWorkspace(_ workspace: Workspace) async throws {
        // Download latest changes from all members
        let changes = try await backend.fetchWorkspaceChanges(
            workspaceId: workspace.id,
            since: workspace.lastSyncedAt
        )
        
        // Apply changes locally
        for change in changes {
            try await applyChange(change)
        }
        
        workspace.lastSyncedAt = Date()
    }
}
```

**2. Dependency Tracking**
```python
# Backend: app/services/dependency_tracker.py
class DependencyTracker:
    """Auto-detects and tracks task dependencies"""
    
    def __init__(self):
        self.llm = ChatAnthropic(model="claude-sonnet-4.5")
        self.graph = KnowledgeGraph()
    
    async def detect_dependencies(
        self,
        task: Dict,
        related_tasks: List[Dict]
    ) -> List[Dict]:
        """Use LLM to detect implicit dependencies"""
        prompt = f"""
        Analyze if this task depends on any other tasks.
        
        New task:
        - Title: {task['title']}
        - Description: {task.get('notes', 'No description')}
        
        Related tasks:
        {json.dumps([{'id': t['id'], 'title': t['title']} for t in related_tasks], indent=2)}
        
        Determine if the new task depends on completing any of the related tasks first.
        Look for indicators like:
        - "after X"
        - "once Y is done"
        - "needs Z"
        - "blocked by"
        - Logical dependencies (e.g., "test feature" depends on "build feature")
        
        Return JSON:
        {{
            "dependencies": [
                {{
                    "task_id": "uuid",
                    "reason": "Why this is a dependency",
                    "type": "hard|soft"
                }}
            ]
        }}
        
        hard = must be done before
        soft = better to do before, but not required
        
        Return ONLY JSON.
        """
        
        response = await self.llm.ainvoke(prompt)
        deps = json.loads(response.content)
        
        return deps.get('dependencies', [])
    
    async def notify_blockers(
        self,
        task_id: str,
        blocking_tasks: List[Dict]
    ):
        """Notify team members about blocking tasks"""
        for blocker in blocking_tasks:
            assignee = blocker.get('assigned_to')
            if assignee:
                await send_notification(
                    user_id=assignee,
                    type='task_blocking',
                    message=f"'{blocker['title']}' is blocking other work",
                    priority='high'
                )
```

**3. Virtual Stand-ups**
```python
# Backend: app/services/standup_generator.py
class StandupGenerator:
    """Generates async standup updates"""
    
    async def generate_standup(
        self,
        user_id: str,
        period: str = "daily"
    ) -> Dict:
        """Generate standup update for user"""
        # Get user's activity
        if period == "daily":
            start = datetime.now() - timedelta(days=1)
        else:
            start = datetime.now() - timedelta(days=7)
        
        activities = await self.get_activities(user_id, start)
        
        # Use LLM to generate update
        prompt = f"""
        Generate a standup update based on this user's activity.
        
        Activity summary:
        - Tasks completed: {activities['completed_tasks']}
        - Tasks in progress: {activities['in_progress_tasks']}
        - Meetings attended: {activities['meetings']}
        - Blockers: {activities['blockers']}
        
        Generate a concise standup update covering:
        1. What I did (2-3 bullets)
        2. What I'm working on (2-3 bullets)
        3. Any blockers (if any)
        
        Keep it brief and actionable.
        Format as markdown.
        """
        
        llm = ChatAnthropic(model="claude-sonnet-4.5")
        response = await llm.ainvoke(prompt)
        
        return {
            "user_id": user_id,
            "period": period,
            "content": response.content,
            "generated_at": datetime.now().isoformat(),
            "activities_summary": activities
        }
    
    async def generate_team_digest(
        self,
        workspace_id: str
    ) -> str:
        """Combine all team members' standups into digest"""
        members = await get_workspace_members(workspace_id)
        standups = []
        
        for member in members:
            standup = await self.generate_standup(member.user_id, "daily")
            standups.append({
                "name": member.name,
                "update": standup['content']
            })
        
        # Format as team digest
        digest = "# Team Daily Standup\n\n"
        for standup in standups:
            digest += f"## {standup['name']}\n{standup['update']}\n\n"
        
        return digest
```

**Deliverables Week 20-22**:
- ✅ Shared workspaces functional
- ✅ Auto-detected task dependencies
- ✅ Team member notifications for blockers
- ✅ AI-generated daily/weekly standups
- ✅ Real-time collaboration basics

---

### Week 23-25: Lifelong Memory & Knowledge Graph

**Objective**: Never forget anything, semantic search across all time.

#### Tasks

**1. Enhanced Semantic Search**
```swift
// Enhanced LifelongMemory.swift
class LifelongMemory {
    private let vectorStore: VectorMemoryStore
    private let backend: BackendService
    
    func search(_ query: String, filters: SearchFilters = .init()) async throws -> SearchResults {
        // Search locally first
        let localResults = try await vectorStore.searchSimilar(
            query: query,
            limit: 10,
            filters: [.type(.task), .type(.event), .type(.interaction)]
        )
        
        // If online, also search backend (has full history)
        var backendResults: [Memory] = []
        if NetworkMonitor.shared.isConnected {
            backendResults = try await backend.searchMemories(
                query: query,
                filters: filters
            )
        }
        
        // Merge and deduplicate
        let combined = mergeResults(local: localResults, backend: backendResults)
        
        // Group by type and time
        return SearchResults(
            query: query,
            results: combined,
            groupedByType: groupByType(combined),
            timeline: createTimeline(combined)
        )
    }
    
    func findRelated(to entityId: UUID) async throws -> [RelatedEntity] {
        // Query knowledge graph
        guard NetworkMonitor.shared.isConnected else {
            return []  // Graph only on backend
        }
        
        return try await backend.findRelatedEntities(
            entityId: entityId,
            maxDepth: 2
        )
    }
    
    func answerQuestion(_ question: String) async throws -> Answer {
        // Use RAG to answer questions about user's history
        let relevantMemories = try await search(
            question,
            filters: SearchFilters(limit: 10)
        )
        
        // Use AI to synthesize answer
        let context = relevantMemories.results
            .map { $0.content }
            .joined(separator: "\n\n")
        
        let aiService = AIService()
        let prompt = """
        Based on the user's history, answer this question:
        
        Question: \(question)
        
        Relevant history:
        \(context)
        
        Provide a specific, factual answer with dates/details.
        """
        
        let response = try await aiService.processIntent(prompt, user: currentUser)
        
        return Answer(
            question: question,
            answer: response.summary,
            sources: relevantMemories.results
        )
    }
}

// UI for semantic search
struct MemorySearchView: View {
    @State private var query = ""
    @State private var results: SearchResults?
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search everything...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
            }
            .padding()
            
            if isSearching {
                ProgressView()
            } else if let results = results {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        // Timeline view
                        TimelineView(results: results)
                        
                        // Grouped results
                        ForEach(results.groupedByType.keys.sorted(), id: \.self) { type in
                            Section(header: Text(type.capitalized).font(.headline)) {
                                ForEach(results.groupedByType[type] ?? []) { result in
                                    MemoryResultRow(memory: result)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Memory Search")
    }
    
    private func