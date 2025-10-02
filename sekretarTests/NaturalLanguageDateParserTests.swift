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

    private func makeReference(year: Int = 2025, month: Int = 10, day: Int = 2, hour: Int = 15, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components)!
    }

    // MARK: - Russian Relative Date Tests

    @Test func parsesTomorrowRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let inputs = ["завтра", "Завтра", "ЗАВТРА"]

        for input in inputs {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let expectedDate = calendar.date(byAdding: .day, value: 1, to: reference)!
            let expectedStart = calendar.startOfDay(for: expectedDate)
            #expect(calendar.startOfDay(for: result!.start) == expectedStart)
        }
    }

    @Test func parsesYesterdayRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let result = parser.parse("вчера", reference: reference)
        #expect(result != nil)

        let expectedDate = calendar.date(byAdding: .day, value: -1, to: reference)!
        let expectedStart = calendar.startOfDay(for: expectedDate)
        #expect(calendar.startOfDay(for: result!.start) == expectedStart)
    }

    @Test func parsesDayAfterTomorrowRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let inputs = ["послезавтра", "после завтра"]

        for input in inputs {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let expectedDate = calendar.date(byAdding: .day, value: 2, to: reference)!
            let expectedStart = calendar.startOfDay(for: expectedDate)
            #expect(calendar.startOfDay(for: result!.start) == expectedStart)
        }
    }

    @Test func parsesInDaysRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("через 3 дня", 3),
            ("через 5 дней", 5),
            ("через 10 дней", 10),
            ("через 1 день", 1)
        ]

        for (input, days) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let expectedDate = calendar.date(byAdding: .day, value: days, to: reference)!
            let expectedStart = calendar.startOfDay(for: expectedDate)
            #expect(calendar.startOfDay(for: result!.start) == expectedStart)
        }
    }

    @Test func parsesInHoursRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("через 2 часа", 2),
            ("через 5 часов", 5),
            ("через 1 час", 1),
            ("через час", 1)
        ]

        for (input, hours) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let expectedDate = calendar.date(byAdding: .hour, value: hours, to: reference)!
            let difference = abs(result!.start.timeIntervalSince(expectedDate))
            #expect(difference < 60) // Within a minute tolerance
        }
    }

    // MARK: - Russian Time Tests

    @Test func parsesExplicitTimeRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("в 14:30", 14, 30),
            ("в 9:00", 9, 0),
            ("в 23:45", 23, 45),
            ("в 00:15", 0, 15)
        ]

        for (input, hour, minute) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let components = calendar.dateComponents([.hour, .minute], from: result!.start)
            #expect(components.hour == hour)
            #expect(components.minute == minute)
        }
    }

    @Test func parsesWordTimeRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("в три часа", 15), // 3 PM in afternoon context
            ("в пять часов", 17), // 5 PM
            ("в десять утра", 10),
            ("в семь вечера", 19),
            ("в полдень", 12),
            ("в полночь", 0)
        ]

        for (input, expectedHour) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let components = calendar.dateComponents([.hour], from: result!.start)
            #expect(components.hour == expectedHour)
        }
    }

    @Test func parsesTimeRangeRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let result = parser.parse("с 14:00 до 16:00", reference: reference)
        #expect(result != nil)
        #expect(result!.end != nil)
        #expect(result!.start < result!.end)
        #expect(calendar.component(.hour, from: result!.start) == 14)
        #expect(calendar.component(.hour, from: result!.end) == 16)
    }

    @Test func parsesTimePeriodsRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("утром", 6...11),
            ("днем", 12...16),
            ("вечером", 17...22)
        ]

        for (input, expectedRange) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let hour = calendar.component(.hour, from: result!.start)
            #expect(expectedRange.contains(hour))
        }
    }

    // MARK: - Russian Duration Tests

    @Test func parsesDurationRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("на 2 часа", 120),
            ("на 30 минут", 30),
            ("на 1 час", 60),
            ("на полчаса", 30),
            ("на час", 60)
        ]

        for (input, expectedMinutes) in testCases {
            let result = parser.parse("встреча завтра в 14:00 \(input)", reference: reference)
            #expect(result != nil)

            if let endDate = result?.end {
                let duration = endDate.timeIntervalSince(result!.start) / 60
                #expect(Int(duration) == expectedMinutes)
            }
        }
    }

    @Test func parsesAllDayRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let inputs = ["весь день", "целый день", "на весь день"]

        for input in inputs {
            let result = parser.parse("завтра \(input)", reference: reference)
            #expect(result != nil)
            #expect(result!.isAllDay == true)
        }
    }

    // MARK: - Russian Month Tests

    @Test func parsesMonthsRussian() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let months = [
            ("15 января", 1),
            ("20 февраля", 2),
            ("10 марта", 3),
            ("5 апреля", 4),
            ("1 мая", 5),
            ("30 июня", 6),
            ("15 июля", 7),
            ("20 августа", 8),
            ("25 сентября", 9),
            ("31 октября", 10),
            ("15 ноября", 11),
            ("25 декабря", 12)
        ]

        for (input, expectedMonth) in months {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let components = calendar.dateComponents([.month], from: result!.start)
            #expect(components.month == expectedMonth)
        }
    }

    // MARK: - English Tests

    @Test func parsesTomorrowEnglish() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let inputs = ["tomorrow", "Tomorrow", "TOMORROW"]

        for input in inputs {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let expectedDate = calendar.date(byAdding: .day, value: 1, to: reference)!
            let expectedStart = calendar.startOfDay(for: expectedDate)
            #expect(calendar.startOfDay(for: result!.start) == expectedStart)
        }
    }

    @Test func parsesInDaysEnglish() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("in 3 days", 3),
            ("in 1 day", 1),
            ("in 10 days", 10)
        ]

        for (input, days) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let expectedDate = calendar.date(byAdding: .day, value: days, to: reference)!
            let expectedStart = calendar.startOfDay(for: expectedDate)
            #expect(calendar.startOfDay(for: result!.start) == expectedStart)
        }
    }

    @Test func parsesTimeEnglish() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("at 2:30 pm", 14, 30),
            ("at 9 am", 9, 0),
            ("at 11:45 pm", 23, 45),
            ("at noon", 12, 0),
            ("at midnight", 0, 0)
        ]

        for (input, hour, minute) in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let components = calendar.dateComponents([.hour, .minute], from: result!.start)
            #expect(components.hour == hour)
            #expect(components.minute == minute)
        }
    }

    @Test func parsesDurationEnglish() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            ("for 2 hours", 120),
            ("for 30 minutes", 30),
            ("for 1 hour", 60)
        ]

        for (input, expectedMinutes) in testCases {
            let result = parser.parse("meeting tomorrow at 2pm \(input)", reference: reference)
            #expect(result != nil)

            if let endDate = result?.end {
                let duration = endDate.timeIntervalSince(result!.start) / 60
                #expect(Int(duration) == expectedMinutes)
            }
        }
    }

    @Test func parsesAllDayEnglish() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let inputs = ["all day", "entire day", "whole day"]

        for input in inputs {
            let result = parser.parse("tomorrow \(input)", reference: reference)
            #expect(result != nil)
            #expect(result!.isAllDay == true)
        }
    }

    // MARK: - Complex Scenarios

    @Test func parsesComplexRussianPhrases() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            "встреча завтра в 14:30 на 2 часа",
            "звонок в пятницу с 10:00 до 11:00",
            "напоминание через 3 дня в 18:00"
        ]

        for input in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)
        }
    }

    @Test func parsesComplexEnglishPhrases() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            "meeting tomorrow at 2:30pm for 2 hours",
            "call on Friday from 10am to 11am",
            "reminder in 3 days at 6pm"
        ]

        for input in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)
        }
    }

    // MARK: - Edge Cases

    @Test func returnsNilForEmptyInput() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let result = parser.parse("", reference: reference)
        #expect(result == nil)
    }

    @Test func returnsNilForNoDateInfo() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let inputs = [
            "просто текст",
            "random text",
            "123456",
            "!!!@@@"
        ]

        for input in inputs {
            let result = parser.parse(input, reference: reference)
            #expect(result == nil)
        }
    }

    @Test func parsesDateFormats() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            "15.03.2025",
            "15/03/2025",
            "15-03-2025",
            "2025-03-15",
            "March 15, 2025",
            "15 March 2025"
        ]

        for input in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)

            let components = calendar.dateComponents([.year, .month, .day], from: result!.start)
            #expect(components.year == 2025)
            #expect(components.month == 3)
            #expect(components.day == 15)
        }
    }

    // MARK: - Mixed Language

    @Test func parsesMixedLanguage() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let testCases = [
            "meeting завтра at 3pm",
            "встреча tomorrow в 15:00"
        ]

        for input in testCases {
            let result = parser.parse(input, reference: reference)
            #expect(result != nil)
        }
    }

    // MARK: - Regression Tests

    @Test func parsesKnownIssues() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()

        // Issue: "в три" without "часа" was not parsed
        let result1 = parser.parse("встреча завтра в три", reference: reference)
        #expect(result1 != nil)

        // Issue: Decimal hours in Russian
        let result2 = parser.parse("на 2.5 часа", reference: reference)
        #expect(result2 != nil)
        if let endDate = result2?.end {
            let duration = endDate.timeIntervalSince(result2!.start) / 60
            #expect(Int(duration) == 150) // 2.5 hours = 150 minutes
        }
    }

    // MARK: - Existing Tests (updated format)

    @Test func parsesTodayEvening() throws {
        let parser = NaturalLanguageDateParser(calendar: calendar)
        let reference = makeReference()
        let result = parser.parse("Создай событие сегодня в 10 вечера", reference: reference)
        #expect(result != nil)
        let start = result!.start
        #expect(calendar.component(.day, from: start) == 2)
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
        let reference = makeReference(day: 2) // 2 Oct 2025 is Thursday
        let result = parser.parse("назначь встречу в понедельник в 9", reference: reference)
        #expect(result != nil)
        #expect(calendar.component(.weekday, from: result!.start) == 2) // Monday
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
