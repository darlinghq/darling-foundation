import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// Locale, time zone and dates go through KVC and NSFormatter's Any-typed API so the test does not
// depend on whether NSLocale, NSTimeZone and NSDate bridge to Swift value types.
let formatter = DateFormatter()
formatter.setValue(NSLocale(localeIdentifier: "en_US_POSIX"), forKey: "locale")
formatter.setValue(NSTimeZone(name: "UTC"), forKey: "timeZone")
formatter.dateFormat = "yyyy-MM-dd-HHmmss"
let date = NSDate(timeIntervalSince1970: 1_626_350_400)
let formatted = formatter.string(for: date) ?? ""
expect(formatted == "2021-07-15-120000", "dateFormat round trip gave \(formatted)")
expect(formatter.string(for: formatter.date(from: "2021-07-15-120000")) == formatted, "date(from:) parses the dateFormat")
expect(formatter.string(for: "not a date") == nil, "string(for:) is nil for a non-date")
var parsed: AnyObject?
var reason: NSString?
expect(formatter.getObjectValue(&parsed, for: "2021-07-15-120000", errorDescription: &reason), "getObjectValue parses")
expect(formatter.string(for: parsed) == formatted, "getObjectValue returns the date")
parsed = nil
expect(!formatter.getObjectValue(&parsed, for: "garbage", errorDescription: &reason) && parsed == nil && reason != nil,
       "getObjectValue rejects an unparseable string")

let mutable = NSMutableString(string: "yyyy")!
formatter.dateFormat = mutable as String
mutable.append("-MM")
expect(formatter.dateFormat == "yyyy", "dateFormat is copied, got \(String(describing: formatter.dateFormat))")

formatter.dateStyle = .medium
formatter.timeStyle = .none
expect(formatter.dateStyle == .medium && formatter.timeStyle == .none, "styles are properties")
formatter.formatterBehavior = .behavior10_4
expect(formatter.formatterBehavior == .behavior10_4, "formatterBehavior")
formatter.isLenient = true
expect(formatter.isLenient, "isLenient")

let styles: [DateFormatter.Style] = [.none, .short, .medium, .long, .full]
expect(styles.map { $0.rawValue } == [0, 1, 2, 3, 4], "DateFormatter.Style raw values")
_ = DateFormatter.localizedString(from:dateStyle:timeStyle:)
formatter.dateFormat = nil
formatter.dateStyle = .medium
expect(!(formatter.dateFormat ?? "").isEmpty && formatter.dateFormat != "yyyy", "dateFormat resets to the style pattern")
let medium = formatter.string(for: date) ?? ""
expect(medium.contains("2021") && !medium.contains(":"), "medium date style, no time style gave \(medium)")
print("PASS: \(formatted), \(medium)")
