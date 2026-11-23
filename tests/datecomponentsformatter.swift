import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// The OpenSwiftUI path: a Calendar value bridged into the formatter's copied calendar.
var calendar = Calendar(identifier: .gregorian)
calendar.locale = Locale(identifier: "de_DE")
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let formatter = DateComponentsFormatter()
formatter.calendar = calendar
formatter.referenceDate = Date(timeIntervalSinceReferenceDate: 0)
expect(formatter.calendar?.locale?.identifier == "de_DE", "calendar keeps its locale")

formatter.unitsStyle = .full
let full = formatter.string(from: 3903)
expect(full == "1 Stunde, 5 Minuten und 3 Sekunden", "full style gave \(full ?? "nil")")

formatter.unitsStyle = .positional
formatter.allowedUnits = [.hour, .minute, .second]
formatter.zeroFormattingBehavior = .pad
let positional = formatter.string(from: 3903)
expect(positional == "01:05:03", "positional style gave \(positional ?? "nil")")

let start = Date(timeIntervalSinceReferenceDate: 0)
expect(formatter.string(from: start, to: start.addingTimeInterval(70)) == "00:01:10", "string(from:to:)")
print("PASS: DateComponentsFormatter")
