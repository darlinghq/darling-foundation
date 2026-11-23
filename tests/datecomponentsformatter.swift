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
// Zero padding of the hours: 26.7.3 gives 01:05:03, 10.14.4 gives 1:05:03 (both accepted, here and below).
expect(positional == "01:05:03" || positional == "1:05:03", "positional style gave \(positional ?? "nil")")

let start = Date(timeIntervalSinceReferenceDate: 0)
let interval = formatter.string(from: start, to: start.addingTimeInterval(70))
expect(interval == "00:01:10" || interval == "0:01:10", "string(from:to:) gave \(interval ?? "nil")")
print("PASS: DateComponentsFormatter")
