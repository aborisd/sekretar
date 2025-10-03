import Foundation

struct DateTimeParsingResult {
    let start: Date
    let end: Date
    let isAllDay: Bool
}

struct NaturalLanguageDateParser {
    private static let monthLookup: [String: Int] = [
        "январ": 1, "feb": 2, "феврал": 2, "mar": 3, "мар": 3,
        "apr": 4, "апрел": 4, "may": 5, "май": 5, "мая": 5,
        "jun": 6, "июн": 6, "jul": 7, "июл": 7, "aug": 8,
        "август": 8, "сент": 9, "sep": 9, "октя": 10, "oct": 10,
        "нояб": 11, "nov": 11, "дека": 12, "dec": 12
    ]

    private static let weekdayLookup: [String: Int] = [
        "monday": 2, "понедель": 2,
        "tuesday": 3, "вторник": 3,
        "wednesday": 4, "сред": 4,
        "thursday": 5, "четверг": 5,
        "friday": 6, "пятниц": 6,
        "saturday": 7, "суббот": 7,
        "sunday": 1, "воскрес": 1
    ]

    private static let wordNumberMap: [String: Int] = [
        "ноль": 0, "zero": 0,
        "один": 1, "одна": 1, "одну": 1, "одно": 1, "one": 1,
        "два": 2, "две": 2, "two": 2, "пару": 2, "couple": 2,
        "три": 3, "three": 3, "несколько": 3, "few": 3,
        "четыре": 4, "четыр": 4, "four": 4,
        "пять": 5, "five": 5,
        "шесть": 6, "six": 6,
        "семь": 7, "seven": 7,
        "восемь": 8, "eight": 8,
        "девять": 9, "nine": 9,
        "десять": 10, "ten": 10,
        "одиннадцать": 11, "одиннадц": 11, "eleven": 11,
        "двенадцать": 12, "двенадц": 12, "twelve": 12,
        "тринадцать": 13, "thirteen": 13,
        "четырнадцать": 14, "fourteen": 14,
        "пятнадцать": 15, "пятнадц": 15, "fifteen": 15, "четверть": 15, "quarter": 15,
        "шестнадцать": 16, "шестнадц": 16, "sixteen": 16,
        "семнадцать": 17, "семнадц": 17, "seventeen": 17,
        "восемнадцать": 18, "восемнадц": 18, "eighteen": 18,
        "девятнадцать": 19, "девятнадц": 19, "nineteen": 19,
        "двадцать": 20, "twenty": 20,
        "тридцать": 30, "thirty": 30, "пол": 30, "половина": 30, "half": 30,
        "сорок": 40, "forty": 40,
        "пятьдесят": 50, "fifty": 50
    ]

    private static let allDayKeywords: [String] = [
        "весь день", "целый день", "all day", "на весь день", "полный день"
    ]

    private static let morningKeywords: [String] = ["утром", "утра", "morning", "am"]
    private static let afternoonKeywords: [String] = ["днем", "дня", "afternoon"]
    private static let eveningKeywords: [String] = ["вечер", "вечером", "вечера", "pm", "evening"]
    private static let nightKeywords: [String] = ["ноч", "ночью", "night"]

    private static let relativeDayPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:через|in)\s+(\d+)\s*(?:дн(?:я|ей|ь)?|day(?:s)?)"#,
            #"через\s+(\d+)\s*сут"#,
            #"in\s+(\d+)\s*night(?:s)?"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static let relativeWeekPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:через|in)\s+(\d+)\s*(?:недел(?:ю|и|ь)?|week(?:s)?)"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static let relativeHourPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:через|in)\s+(\d+)\s*(?:час(?:а|ов)?|hour(?:s)?|h)"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static let relativeMinutePatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:через|in)\s+(\d+)\s*(?:минут(?:ы|у)?|minute(?:s)?|m)"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    // НОВОЕ: Расширенные относительные паттерны (из ai_calendar_production_plan_v4.md)
    private static let advancedRelativePatterns: [String: (Calendar, Date) -> Date?] = [
        // Конец месяца
        "в конце месяца": { cal, ref in
            guard let range = cal.range(of: .day, in: .month, for: ref),
                  let lastDay = cal.date(bySetting: .day, value: range.upperBound - 1, of: ref) else {
                return nil
            }
            return cal.date(bySettingHour: 18, minute: 0, second: 0, of: lastDay)
        },
        "at the end of the month": { cal, ref in
            guard let range = cal.range(of: .day, in: .month, for: ref),
                  let lastDay = cal.date(bySetting: .day, value: range.upperBound - 1, of: ref) else {
                return nil
            }
            return cal.date(bySettingHour: 18, minute: 0, second: 0, of: lastDay)
        },
        // Начало месяца
        "в начале месяца": { cal, ref in
            guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: ref)) else {
                return nil
            }
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: firstDay)
        },
        "at the beginning of the month": { cal, ref in
            guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: ref)) else {
                return nil
            }
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: firstDay)
        },
        // Следующая неделя
        "на следующей неделе": { cal, ref in
            guard let nextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: ref),
                  let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextWeek)) else {
                return nil
            }
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: monday)
        },
        "next week": { cal, ref in
            guard let nextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: ref),
                  let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextWeek)) else {
                return nil
            }
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: monday)
        },
        // Конец недели
        "в конце недели": { cal, ref in
            guard let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)),
                  let friday = cal.date(byAdding: .day, value: 4, to: startOfWeek) else {
                return nil
            }
            return cal.date(bySettingHour: 17, minute: 0, second: 0, of: friday)
        },
        "end of the week": { cal, ref in
            guard let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)),
                  let friday = cal.date(byAdding: .day, value: 4, to: startOfWeek) else {
                return nil
            }
            return cal.date(bySettingHour: 17, minute: 0, second: 0, of: friday)
        }
    ]

    private var calendar: Calendar
    private let locale: Locale

    init(calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }()) {
        var cal = calendar
        if cal.locale == nil { cal.locale = Locale(identifier: "ru_RU") }
        self.calendar = cal
        self.locale = cal.locale ?? Locale(identifier: "ru_RU")
    }

    func parse(_ text: String, reference: Date = Date()) -> DateTimeParsingResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        if let interval = parseRelativeTimeInterval(in: lower) {
            let start = reference.addingTimeInterval(interval)
            let duration = parseExplicitDuration(in: lower) ?? 3600
            return DateTimeParsingResult(start: start, end: start.addingTimeInterval(duration), isAllDay: false)
        }

        var baseDay = calendar.startOfDay(for: reference)
        var matchedDay = false

        // НОВОЕ: Проверяем расширенные относительные паттерны сначала
        for (pattern, handler) in Self.advancedRelativePatterns {
            if lower.contains(pattern) {
                if let date = handler(calendar, reference) {
                    let duration = parseExplicitDuration(in: lower) ?? 3600
                    return DateTimeParsingResult(start: date, end: date.addingTimeInterval(duration), isAllDay: false)
                }
            }
        }

        if let explicitDate = parseExplicitDate(in: lower, reference: reference) {
            baseDay = calendar.startOfDay(for: explicitDate)
            matchedDay = true
        } else if let weekdayDate = parseWeekday(in: lower, reference: reference) {
            baseDay = calendar.startOfDay(for: weekdayDate)
            matchedDay = true
        } else if lower.contains("послезавтра") || lower.contains("day after") {
            baseDay = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: reference)) ?? baseDay
            matchedDay = true
        } else if lower.contains("завтра") || lower.contains("tomorrow") {
            baseDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)) ?? baseDay
            matchedDay = true
        } else if lower.contains("сегодня") || lower.contains("today") {
            baseDay = calendar.startOfDay(for: reference)
            matchedDay = true
        } else if let daysOffset = parseRelativeDays(in: lower) {
            baseDay = calendar.date(byAdding: .day, value: daysOffset, to: calendar.startOfDay(for: reference)) ?? baseDay
            matchedDay = true
        } else if let weeksOffset = parseRelativeWeeks(in: lower) {
            baseDay = calendar.date(byAdding: .day, value: weeksOffset * 7, to: calendar.startOfDay(for: reference)) ?? baseDay
            matchedDay = true
        }

        let periodHint = detectPeriodHint(in: lower)
        var matchedTime = false
        var isAllDay = Self.allDayKeywords.contains { lower.contains($0) }

        if let range = parseExplicitTimeRange(in: lower, baseDay: baseDay, periodHint: periodHint) {
            matchedTime = true
            isAllDay = false
            return DateTimeParsingResult(start: range.start, end: range.end, isAllDay: false)
        }

        if let single = parseSingleTime(in: lower, baseDay: baseDay, periodHint: periodHint) {
            matchedTime = true
            let duration = parseExplicitDuration(in: lower) ?? 3600
            return DateTimeParsingResult(start: single, end: single.addingTimeInterval(duration), isAllDay: false)
        }

        if let approx = parseApproximatePeriod(in: lower, baseDay: baseDay) {
            matchedTime = true
            let duration = parseExplicitDuration(in: lower) ?? 5400
            return DateTimeParsingResult(start: approx, end: approx.addingTimeInterval(duration), isAllDay: false)
        }

        if !matchedDay && !matchedTime {
            if let detectorResult = parseUsingDataDetector(in: trimmed, reference: reference) {
                return detectorResult
            }
            return nil
        }

        if !isAllDay && !matchedTime {
            // We know the date but no time — treat as all-day by default
            isAllDay = true
        }

        if isAllDay {
            let endDay = calendar.date(byAdding: .day, value: 1, to: baseDay) ?? baseDay.addingTimeInterval(86400)
            return DateTimeParsingResult(start: baseDay, end: endDay, isAllDay: true)
        }

        // Fallback: date known but no time, default to midday block
        guard let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDay) else { return nil }
        let duration = parseExplicitDuration(in: lower) ?? 3600
        return DateTimeParsingResult(start: start, end: start.addingTimeInterval(duration), isAllDay: false)
    }
}

private extension NaturalLanguageDateParser {
    func parseExplicitDate(in text: String, reference: Date) -> Date? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = try? NSRegularExpression(pattern: #"(\d{1,2})\s*(?:го\s*)?([a-zA-Zа-яё]+)(?:\s*(\d{2,4}))?"#, options: [.caseInsensitive])
            .firstMatch(in: text, options: [], range: range),
           let dayRange = Range(match.range(at: 1), in: text),
           let monthRange = Range(match.range(at: 2), in: text) {
            let day = Int(text[dayRange]) ?? 1
            let monthKey = normalizeMonthKey(String(text[monthRange]))
            if let month = Self.monthLookup.first(where: { monthKey.hasPrefix($0.key) })?.value {
                var comps = calendar.dateComponents([.year], from: reference)
                if let yearRange = Range(match.range(at: 3), in: text) {
                    let yearString = text[yearRange]
                    if yearString.count == 2 {
                        let prefix = calendar.component(.year, from: reference) / 100
                        comps.year = prefix * 100 + (Int(yearString) ?? 0)
                    } else {
                        comps.year = Int(yearString) ?? comps.year
                    }
                }
                comps.month = month
                comps.day = day
                comps.hour = 12
                comps.minute = 0
                if let date = calendar.date(from: comps) {
                    if date < reference, match.range(at: 3).location == NSNotFound {
                        var nextYearComps = comps
                        nextYearComps.year = (comps.year ?? calendar.component(.year, from: reference)) + 1
                        if let next = calendar.date(from: nextYearComps) { return next }
                    }
                    return date
                }
            }
        }

        if let match = try? NSRegularExpression(pattern: #"\b(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?"#, options: [])
            .firstMatch(in: text, options: [], range: range),
           let dayRange = Range(match.range(at: 1), in: text),
           let monthRange = Range(match.range(at: 2), in: text) {
            let day = Int(text[dayRange]) ?? 1
            let month = Int(text[monthRange]) ?? 1
            var comps = calendar.dateComponents([.year], from: reference)
            if let yearRange = Range(match.range(at: 3), in: text) {
                let yearString = text[yearRange]
                if yearString.count == 2 {
                    let prefix = calendar.component(.year, from: reference) / 100
                    comps.year = prefix * 100 + (Int(yearString) ?? 0)
                } else {
                    comps.year = Int(yearString) ?? comps.year
                }
            }
            comps.month = month
            comps.day = day
            comps.hour = 12
            comps.minute = 0
            if let date = calendar.date(from: comps) {
                if date < reference, match.range(at: 3).location == NSNotFound {
                    var nextYearComps = comps
                    nextYearComps.year = (comps.year ?? calendar.component(.year, from: reference)) + 1
                    if let next = calendar.date(from: nextYearComps) { return next }
                }
                return date
            }
        }

        return nil
    }

    func parseWeekday(in text: String, reference: Date) -> Date? {
        for (key, weekday) in Self.weekdayLookup {
            if text.contains(key) {
                let refWeekday = calendar.component(.weekday, from: reference)
                if refWeekday == weekday {
                    return calendar.startOfDay(for: reference)
                }
                var components = DateComponents()
                components.weekday = weekday
                components.hour = 0
                components.minute = 0
                if let next = calendar.nextDate(after: reference, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first, direction: .forward) {
                    return next
                }
            }
        }

        if text.contains("на выходных") || text.contains("this weekend") {
            let weekday = calendar.component(.weekday, from: reference)
            if weekday == 7 || weekday == 1 {
                return calendar.startOfDay(for: reference)
            }
            var components = DateComponents()
            components.weekday = 7
            components.hour = 0
            components.minute = 0
            if let saturday = calendar.nextDate(after: reference, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first, direction: .forward) {
                return saturday
            }
        }

        return nil
    }

    func parseRelativeDays(in text: String) -> Int? {
        for regex in Self.relativeDayPatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text),
               let offset = Int(text[valueRange]) {
                return offset
            }
        }
        if let wordOffset = extractWordBasedOffset(in: text, unitKeywords: ["день", "дня", "дней", "day", "days", "сут"] ) {
            return wordOffset
        }
        if text.contains("послезавтра") { return 2 }
        if text.contains("завтра") { return 1 }
        return nil
    }

    func parseRelativeWeeks(in text: String) -> Int? {
        for regex in Self.relativeWeekPatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text),
               let offset = Int(text[valueRange]) {
                return offset
            }
        }
        if let wordOffset = extractWordBasedOffset(in: text, unitKeywords: ["нед", "week"]) {
            return wordOffset
        }
        return nil
    }

    func parseRelativeTimeInterval(in text: String) -> TimeInterval? {
        var total: TimeInterval = 0
        var matched = false

        for regex in Self.relativeHourPatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text) {
                let valueString = text[valueRange].replacingOccurrences(of: ",", with: ".")
                if let hours = Double(valueString) {
                    total += hours * 3600
                    matched = true
                }
            }
        }

        for regex in Self.relativeMinutePatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text) {
                let valueString = text[valueRange].replacingOccurrences(of: ",", with: ".")
                if let minutes = Double(valueString) {
                    total += minutes * 60
                    matched = true
                }
            }
        }

        if let hourOffset = extractWordBasedOffset(in: text, unitKeywords: ["час", "часа", "часов", "hour", "hours"]) {
            total += Double(hourOffset) * 3600
            matched = true
        }
        if let minuteOffset = extractWordBasedOffset(in: text, unitKeywords: ["минут", "minute", "мин", "min"]) {
            total += Double(minuteOffset) * 60
            matched = true
        }

        if text.contains("полтора часа") || text.contains("hour and a half") { total += 1.5 * 3600; matched = true }
        if text.contains("полчаса") || text.contains("half an hour") { total += 0.5 * 3600; matched = true }

        return matched ? total : nil
    }

    func parseExplicitTimeRange(in text: String, baseDay: Date, periodHint: DayPeriod?) -> (start: Date, end: Date)? {
        let pattern = #"(?:(?:с|from|between|между)\s*)(\d{1,2})(?:[:.](\d{2}))?\s*(утра|утром|вечера|вечером|дня|ночи|pm|am|morning|evening|afternoon|night)?\s*(?:до|and|по|\-|—)\s*(\d{1,2})(?:[:.](\d{2}))?\s*(утра|утром|вечера|вечером|дня|ночи|pm|am|morning|evening|afternoon|night)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        guard let startHourRange = Range(match.range(at: 1), in: text) else { return nil }
        let startHour = Int(text[startHourRange]) ?? 0
        let startMinute = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
        let startSuffix = Range(match.range(at: 3), in: text).map { String(text[$0]) }

        guard let endHourRange = Range(match.range(at: 4), in: text) else { return nil }
        let endHour = Int(text[endHourRange]) ?? 0
        let endMinute = Range(match.range(at: 5), in: text).flatMap { Int(text[$0]) } ?? 0
        let endSuffix = Range(match.range(at: 6), in: text).map { String(text[$0]) }

        let normalizedEndSuffix = endSuffix ?? startSuffix

        let startHour24 = interpretHour(startHour, suffix: startSuffix, fallback: normalizedEndSuffix, hint: periodHint)
        let endHour24 = interpretHour(endHour, suffix: endSuffix, fallback: startSuffix ?? normalizedEndSuffix, hint: periodHint)

        guard let start = calendar.date(bySettingHour: startHour24, minute: startMinute, second: 0, of: baseDay) else { return nil }
        guard var end = calendar.date(bySettingHour: endHour24, minute: endMinute, second: 0, of: baseDay) else { return nil }
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? start.addingTimeInterval(3600)
        }
        return (start, end)
    }

    func parseSingleTime(in text: String, baseDay: Date, periodHint: DayPeriod?) -> Date? {
        // Updated pattern to better capture "часа дня" and similar constructs
        let pattern = #"(?:(?:в|к|на|at|по)\s*)(\d{1,2})(?:[:.](\d{2}))?\s*(?:час(?:а|ов)?\s*)?(утра|утром|вечера|вечером|дня|ночи|pm|am|morning|evening|afternoon|night)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            guard let hourRange = Range(match.range(at: 1), in: text) else { return nil }
            let hour = Int(text[hourRange]) ?? 0
            let minute = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
            let suffix = Range(match.range(at: 3), in: text).map { String(text[$0]) }
            let adjustedHour = interpretHour(hour, suffix: suffix, fallback: nil, hint: periodHint)
            return calendar.date(bySettingHour: adjustedHour, minute: minute, second: 0, of: baseDay)
        }

        let patternTight = #"\b(\d{1,2})(?:[:.](\d{2}))?(pm|am)\b"#
        if let regex = try? NSRegularExpression(pattern: patternTight, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: text, options: [], range: range) {
            guard let hourRange = Range(match.range(at: 1), in: text) else { return nil }
            let hour = Int(text[hourRange]) ?? 0
            let minute = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
            let suffix = Range(match.range(at: 3), in: text).map { String(text[$0]) }
            let adjustedHour = interpretHour(hour, suffix: suffix, fallback: nil, hint: periodHint)
            return calendar.date(bySettingHour: adjustedHour, minute: minute, second: 0, of: baseDay)
        }

        if let wordBased = parseWordBasedSingleTime(in: text, baseDay: baseDay, periodHint: periodHint) {
            return wordBased
        }

        return nil
    }

    func parseWordBasedSingleTime(in text: String, baseDay: Date, periodHint: DayPeriod?) -> Date? {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return nil }
        let prepositions: Set<String> = ["в", "во", "к", "на", "at", "по"]

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if !prepositions.contains(token) {
                index += 1
                continue
            }

            let hourIndex = index + 1
            guard hourIndex < tokens.count else { break }
            let hourToken = tokens[hourIndex]
            var hourValue: Int?

            // Handle compounds like "двадцать" "два"
            if hourToken == "двадцать" || hourToken == "twenty" {
                let nextIndex = hourIndex + 1
                if nextIndex < tokens.count, let nextValue = Self.wordNumberMap[tokens[nextIndex]] {
                    hourValue = 20 + nextValue
                    index = nextIndex
                } else {
                    hourValue = 20
                }
            } else if let mapped = Self.wordNumberMap[hourToken] {
                hourValue = mapped
            }

            guard var hour = hourValue else {
                index += 1
                continue
            }

            var minute = 0
            var cursor = index + 2
            if cursor < tokens.count {
                let potentialMinute = tokens[cursor]
                if let mappedMinute = Self.wordNumberMap[potentialMinute], mappedMinute < 60 {
                    minute = mappedMinute
                    cursor += 1
                } else if potentialMinute == "тридцать" || potentialMinute == "thirty" {
                    minute = 30
                    cursor += 1
                } else if potentialMinute == "сорок" || potentialMinute == "forty" {
                    minute = 40
                    cursor += 1
                    if cursor < tokens.count, let extra = Self.wordNumberMap[tokens[cursor]], extra < 10 {
                        minute += extra
                        cursor += 1
                    }
                } else if potentialMinute == "пятнадцать" || potentialMinute == "quarter" || potentialMinute == "четверть" {
                    minute = 15
                    cursor += 1
                } else if potentialMinute == "пол" || potentialMinute == "половина" || potentialMinute == "half" {
                    minute = 30
                    cursor += 1
                }
            }

            var suffix: String?
            if cursor < tokens.count {
                suffix = tokens[cursor]
            }

            hour = interpretHour(hour, suffix: suffix, fallback: nil, hint: periodHint)
            if let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDay) {
                return date
            }

            index = cursor
        }

        return nil
    }

    func parseApproximatePeriod(in text: String, baseDay: Date) -> Date? {
        if Self.morningKeywords.contains(where: { text.contains($0) }) {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDay)
        }
        if Self.afternoonKeywords.contains(where: { text.contains($0) }) {
            return calendar.date(bySettingHour: 13, minute: 0, second: 0, of: baseDay)
        }
        if Self.eveningKeywords.contains(where: { text.contains($0) }) {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: baseDay)
        }
        if Self.nightKeywords.contains(where: { text.contains($0) }) {
            return calendar.date(bySettingHour: 22, minute: 0, second: 0, of: baseDay)
        }
        if text.contains("полдень") || text.contains("noon") {
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDay)
        }
        if text.contains("полноч") || text.contains("midnight") {
            return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: baseDay)
        }
        return nil
    }

    func parseExplicitDuration(in text: String) -> TimeInterval? {
        if let regex = try? NSRegularExpression(pattern: #"(?:на|for)\s+(\d+)[,.]?(\d+)?\s*(час(?:а|ов)?|hour(?:s)?|h)"#, options: [.caseInsensitive]) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text),
               let hours = Double(text[valueRange]) {
                var fraction: Double = 0
                if let fractionRange = Range(match.range(at: 2), in: text) {
                    let fractionString = String(text[fractionRange])
                    if let fractionValue = Double(fractionString) {
                        fraction = fractionValue / pow(10, Double(fractionString.count))
                    }
                }
                return (hours + fraction) * 3600
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"(?:на|for)\s+(\d+)[,.]?(\d+)?\s*(минут(?:ы|у)?|minute(?:s)?|m)"#, options: [.caseInsensitive]) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text),
               let minutes = Double(text[valueRange]) {
                var fraction: Double = 0
                if let fractionRange = Range(match.range(at: 2), in: text) {
                    let fractionString = String(text[fractionRange])
                    if let fractionValue = Double(fractionString) {
                        fraction = fractionValue / pow(10, Double(fractionString.count))
                    }
                }
                return (minutes + fraction) * 60
            }
        }
        if text.contains("на полтора часа") { return 1.5 * 3600 }
        if text.contains("на полчаса") { return 0.5 * 3600 }
        if text.contains("for an hour and a half") { return 1.5 * 3600 }
        if text.contains("for half an hour") { return 0.5 * 3600 }
        return nil
    }

    func parseUsingDataDetector(in text: String, reference: Date) -> DateTimeParsingResult? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        guard let match = matches.sorted(by: { $0.range.location < $1.range.location }).first, let detectedDate = match.date else {
            return nil
        }

        var start = detectedDate
        if let timeZone = match.timeZone {
            let delta = TimeInterval(timeZone.secondsFromGMT(for: detectedDate) - TimeZone.current.secondsFromGMT(for: detectedDate))
            if abs(delta) > 1 { start = start.addingTimeInterval(delta) }
        }

        let explicit = parseExplicitDuration(in: text)
        let duration = match.duration > 0 ? match.duration : (explicit ?? 3600)
        var end = start.addingTimeInterval(duration)
        var isAllDay = false

        if duration >= 20 * 3600 || (!text.contains(":") && !text.contains(".") && !text.lowercased().contains("am") && !text.lowercased().contains("pm")) {
            let dayStart = calendar.startOfDay(for: start)
            start = dayStart
            end = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
            isAllDay = true
        }

        return DateTimeParsingResult(start: start, end: end, isAllDay: isAllDay)
    }

    func interpretHour(_ hour: Int, suffix: String?, fallback: String?, hint: DayPeriod?) -> Int {
        var h = hour % 24
        let suffixLower = suffix?.lowercased()
        let fallbackLower = fallback?.lowercased()
        let appliedSuffix = suffixLower ?? fallbackLower

        if let appliedSuffix {
            // First check for afternoon keywords including "дня"
            if containsAny(in: appliedSuffix, keywords: Self.afternoonKeywords + ["дня"]) && h < 12 {
                h += 12
            } else if containsAny(in: appliedSuffix, keywords: Self.eveningKeywords + ["pm"]) && h < 12 {
                h += 12
            } else if containsAny(in: appliedSuffix, keywords: Self.morningKeywords + ["am", "morning"]) {
                if h == 12 { h = 0 }
            } else if containsAny(in: appliedSuffix, keywords: Self.nightKeywords) {
                if h == 12 { h = 0 }
            }
        } else if let hint {
            switch hint {
            case .evening, .afternoon:
                if h < 12 { h += 12 }
            case .night:
                if h == 12 { h = 0 }
            case .morning:
                if h == 12 { h = 0 }
            }
        }

        if h >= 24 { h -= 24 }
        return h
    }

    func detectPeriodHint(in text: String) -> DayPeriod? {
        if containsAny(in: text, keywords: Self.eveningKeywords) { return .evening }
        if containsAny(in: text, keywords: Self.afternoonKeywords) { return .afternoon }
        if containsAny(in: text, keywords: Self.morningKeywords) { return .morning }
        if containsAny(in: text, keywords: Self.nightKeywords) { return .night }
        return nil
    }

    func containsAny(in text: String, keywords: [String]) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) { return true }
        }
        return false
    }

    func extractWordBasedOffset(in text: String, unitKeywords: [String]) -> Int? {
        let tokens = tokenize(text)
        let skipWords: Set<String> = ["и", "and", "рабочих", "рабочий", "рабочие", "working", "business", "work"]

        for (index, token) in tokens.enumerated() {
            guard token == "через" || token == "in" else { continue }
            guard index + 1 < tokens.count else { continue }
            let numberToken = tokens[index + 1]
            guard let value = Self.wordNumberMap[numberToken] else { continue }

            let searchUpperBound = min(tokens.count, index + 6)
            var candidateIndex = index + 2
            while candidateIndex < searchUpperBound {
                let candidate = tokens[candidateIndex]
                if unitKeywords.contains(where: { candidate.hasPrefix($0) }) {
                    return value
                }
                if candidate == "через" { break }
                if Self.wordNumberMap[candidate] != nil { break }
                if !skipWords.contains(candidate) {
                    // allow descriptors but continue scanning limited range
                }
                candidateIndex += 1
            }
        }
        return nil
    }

    func tokenize(_ text: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return text.lowercased().components(separatedBy: separators).filter { !$0.isEmpty }
    }

    func normalizeMonthKey(_ value: String) -> String {
        value.lowercased().folding(options: .diacriticInsensitive, locale: locale)
    }
}

private enum DayPeriod {
    case morning
    case afternoon
    case evening
    case night
}
