import Testing
@testable import sekretar
import Foundation

struct NaturalLanguageDateParserTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    private func makeReference(year: Int = 2024, month: Int = 9, day: Int = 27, hour: Int = 10, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components)!
    }

    @Test func parsesTodayEvening() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let result = parser.parse("Создай событие сегодня в 10 вечера", reference: reference)
        #expect(result != nil)
        let start = result!.start
        #expect(calendar.component(.day, from: start) == 27)
        #expect(calendar.component(.hour, from: start) == 22)
        #expect(result!.isAllDay == false)
    }

    @Test func parsesRelativeDayWords() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference(day: 12)
        let result = parser.parse("напомни через два дня", reference: reference)
        #expect(result != nil)
        let start = calendar.startOfDay(for: result!.start)
        let expected = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: reference))!
        #expect(start == expected)
        #expect(result!.isAllDay == false)
    }

    @Test func parsesExplicitDateAndTime() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference(day: 1)
        let result = parser.parse("встреть меня 29 сентября в 15:30", reference: reference)
        #expect(result != nil)
        #expect(calendar.component(.day, from: result!.start) == 29)
        #expect(calendar.component(.hour, from: result!.start) == 15)
        #expect(calendar.component(.minute, from: result!.start) == 30)
    }

    @Test func parsesTimeRange() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let result = parser.parse("забронируй слот с 13 до 15", reference: reference)
        #expect(result != nil)
        #expect(result!.start < result!.end)
        #expect(calendar.component(.hour, from: result!.start) == 13)
        #expect(calendar.component(.hour, from: result!.end) == 15)
    }

    @Test func parsesWeekday() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference(day: 27) // 27 Sep 2024 is Friday
        let result = parser.parse("назначь встречу в понедельник в 9", reference: reference)
        #expect(result != nil)
        #expect(calendar.component(.weekday, from: result!.start) == 2)
        #expect(calendar.component(.hour, from: result!.start) == 9)
    }

    @Test func parsesRelativeHours() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference(hour: 8)
        let result = parser.parse("слот через 3 часа на 30 минут", reference: reference)
        #expect(result != nil)
        let delta = result!.start.timeIntervalSince(reference)
        #expect(delta == 3 * 3600)
        #expect(result!.end.timeIntervalSince(result!.start) == 1800)
    }

    @Test func parsesSpelledOutTime() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference(day: 10, hour: 12)
        let result = parser.parse("создай задачу на девять утра завтра", reference: reference)
        #expect(result != nil)
        let components = calendar.dateComponents([.day, .hour, .minute], from: result!.start)
        #expect(components.day == 11)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test func parsesSpelledOutMinutes() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference(day: 5, hour: 14)
        let result = parser.parse("забронируй звонок в семь тридцать вечера", reference: reference)
        #expect(result != nil)
        let components = calendar.dateComponents([.hour, .minute], from: result!.start)
        #expect(components.hour == 19)
        #expect(components.minute == 30)
    }
}
