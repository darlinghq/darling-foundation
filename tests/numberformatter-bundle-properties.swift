import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// As on macOS, the NSNumberFormatter configuration and the bundle info dictionaries import as properties.
let formatter = NumberFormatter()
formatter.locale = Locale(identifier: "en_US")
formatter.numberStyle = .decimal
formatter.minimumFractionDigits = 1
formatter.maximumFractionDigits = 3
formatter.isLenient = true
let minimum: Int = formatter.minimumFractionDigits
expect(minimum == 1 && formatter.maximumFractionDigits == 3, "fraction digits")
expect(formatter.isLenient, "isLenient")
expect(formatter.string(from: 2) == "2.0", "minimum fraction digits applied")
expect(formatter.string(from: 1.23456) == "1.235", "maximum fraction digits applied")

let bundle: Bundle = Bundle(for: NumberFormatter.self)
let info: [String: Any]? = bundle.infoDictionary
expect(info?["CFBundleIdentifier"] as? String == bundle.bundleIdentifier, "infoDictionary")
let localized: [String: Any]? = bundle.localizedInfoDictionary
expect(localized == nil || localized?["CFBundleIdentifier"] == nil
    || localized?["CFBundleIdentifier"] as? String == bundle.bundleIdentifier, "localizedInfoDictionary")
print("PASS: NumberFormatter and Bundle info properties")
