import Testing
import CoreData
@testable import sekretar

struct CalendarViewModelTests {
    private func makeInMemoryContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @Test func testSelectDateLoadsEvents() async throws {
        let context = makeInMemoryContext()
        let event = EventEntity(context: context)
        event.id = UUID()
        event.title = "Встреча"
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2024
        components.month = 5
        components.day = 14
        components.hour = 10
        let date = calendar.date(from: components)!
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.isAllDay = false
        try context.save()

        let viewModel = await MainActor.run { CalendarViewModel(context: context) }
        await MainActor.run { viewModel.selectDate(date) }
        try await Task.sleep(nanoseconds: 200_000_000) // allow async fetch

        let eventsForDay = await MainActor.run { viewModel.eventsFor(date: date) }
        #expect(eventsForDay.count == 1)
        #expect(eventsForDay.first?.title == "Встреча")
    }

    @Test func testNavigateNextDayAdvancesCurrentDate() async throws {
        let context = makeInMemoryContext()
        let viewModel = await MainActor.run { CalendarViewModel(context: context) }
        let initial = await MainActor.run { viewModel.currentDate }
        await MainActor.run {
            viewModel.switchViewMode(.day)
            viewModel.navigateNext()
        }
        let advanced = await MainActor.run { viewModel.currentDate }
        #expect(advanced > initial)
    }
}
