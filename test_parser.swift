import Foundation

// Test the parser
let parser = NaturalLanguageDateParser()
let testDate = Date() // Current date

let testCases = [
    "завтра в 3 часа дня",
    "сегодня в 3 часа дня",
    "в 3 часа дня",
    "3 часа дня"
]

let formatter = DateFormatter()
formatter.dateFormat = "d MMM yyyy, HH:mm"
formatter.locale = Locale(identifier: "ru_RU")

print("Reference date: \(formatter.string(from: testDate))")
print("---")

for test in testCases {
    if let result = parser.parse(test, reference: testDate) {
        print("\"\(test)\":")
        print("  Start: \(formatter.string(from: result.start))")
        print("  End: \(formatter.string(from: result.end))")
    } else {
        print("\"\(test)\": Failed to parse")
    }
    print()
}