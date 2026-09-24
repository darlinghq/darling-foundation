import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// OpenSwiftUI configures formatters from the environment this way.
extension ISO8601DateFormatter {
    func configure(timeZone zone: TimeZone) {
        timeZone = zone
    }
}

let date = Date(timeIntervalSince1970: 1_626_350_400)
let formatter = ISO8601DateFormatter()
expect(formatter.formatOptions == .withInternetDateTime, "default options")
expect(formatter.string(from: date) == "2021-07-15T12:00:00Z", "default format")
formatter.configure(timeZone: TimeZone(secondsFromGMT: 7200)!)
expect(formatter.string(from: date) == "2021-07-15T14:00:00+02:00", "time zone")
expect(formatter.date(from: "2021-07-15T14:00:00+02:00") == date, "parse")
formatter.timeZone = nil
expect(formatter.timeZone.secondsFromGMT(for: date) == 0, "nil resets to GMT")
formatter.formatOptions = [.withFullDate]
expect(formatter.string(from: date) == "2021-07-15", "withFullDate")
let options: ISO8601DateFormatter.Options = [.withYear, .withWeekOfYear, .withDay, .withDashSeparatorInDate]
expect(ISO8601DateFormatter.string(from: date, timeZone: TimeZone(identifier: "GMT")!, formatOptions: options) == "2021-W28-04",
       "class string(from:timeZone:formatOptions:)")
print("PASS: ISO8601DateFormatter")
