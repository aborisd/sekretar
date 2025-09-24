import Foundation
import EventKit
import CoreData

protocol EventKitServiceProtocol {
    func requestAccess() async -> Bool
    func events(for date: Date) async -> [EKEvent]
    func importEvents(from startDate: Date, to endDate: Date) async throws
    func syncToEventKit(_ event: EventEntity) async throws
    func deleteFromEventKit(eventKitId: String) async throws
}

@MainActor
final class EventKitService: ObservableObject, EventKitServiceProtocol {
    private let store = EKEventStore()
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func requestAccess() async -> Bool {
        if #available(iOS 17, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
            }
        }
    }

    func events(for date: Date) async -> [EKEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }
    
    func importEvents(from startDate: Date, to endDate: Date) async throws {
        let hasAccess = await requestAccess()
        guard hasAccess else { throw EventKitError.accessDenied }
        
        let pred = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = store.events(matching: pred)
        
        await context.perform {
            for ekEvent in ekEvents {
                // Check if event already exists
                let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "eventKitId == %@", ekEvent.eventIdentifier)
                
                do {
                    let existingEvents = try self.context.fetch(fetchRequest)
                    
                    if existingEvents.isEmpty {
                        // Create new EventEntity
                        let event = EventEntity(context: self.context)
                        event.id = UUID()
                        event.title = ekEvent.title
                        event.startDate = ekEvent.startDate
                        event.endDate = ekEvent.endDate
                        event.isAllDay = ekEvent.isAllDay
                        event.notes = ekEvent.notes
                        event.eventKitId = ekEvent.eventIdentifier
                    } else {
                        // Update existing event
                        let event = existingEvents.first!
                        event.title = ekEvent.title
                        event.startDate = ekEvent.startDate
                        event.endDate = ekEvent.endDate
                        event.isAllDay = ekEvent.isAllDay
                        event.notes = ekEvent.notes
                    }
                } catch {
                    print("Import error: \(error)")
                }
            }
            
            try? self.context.save()
        }
    }
    
    func syncToEventKit(_ event: EventEntity) async throws {
        let hasAccess = await requestAccess()
        guard hasAccess else { throw EventKitError.accessDenied }
        
        let ekEvent: EKEvent
        
        if let eventKitId = event.eventKitId,
           let existingEvent = store.event(withIdentifier: eventKitId) {
            ekEvent = existingEvent
        } else {
            ekEvent = EKEvent(eventStore: store)
            ekEvent.calendar = store.defaultCalendarForNewEvents
        }
        
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.isAllDay = event.isAllDay
        ekEvent.notes = event.notes
        
        try store.save(ekEvent, span: .thisEvent)
        
        // Update the EventEntity with the EventKit ID
        await context.perform {
            event.eventKitId = ekEvent.eventIdentifier
            try? self.context.save()
        }
    }

    func deleteFromEventKit(eventKitId: String) async throws {
        let hasAccess = await requestAccess()
        guard hasAccess else { throw EventKitError.accessDenied }
        if let existing = store.event(withIdentifier: eventKitId) {
            try store.remove(existing, span: .thisEvent)
        }
    }
}

enum EventKitError: Error {
    case accessDenied
    case saveFailed
    case eventNotFound
}
