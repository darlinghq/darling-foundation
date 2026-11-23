import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// As on macOS: the initializers are non-failable and the enumeration blocks are non-escaping,
// so a closure may call methods on self without an explicit `self.`.
final class Collector {
    var ranges: [NSRange] = []
    var values: [String] = []
    func record(_ range: NSRange) { ranges.append(range) }
    func note(_ value: Any?) { values.append(value as? String ?? "-") }

    func run() {
        let key = NSAttributedString.Key("DarlingTestKey")
        let plain = NSAttributedString(string: "ab")
        let tagged = NSAttributedString(string: "cd", attributes: [key: "x"])
        let copy = NSAttributedString(attributedString: tagged)
        let joined = NSMutableAttributedString(attributedString: plain)
        joined.append(copy)
        joined.enumerateAttributes(in: NSMakeRange(0, joined.length), options: []) { _, range, _ in
            record(range)
        }
        // Without longestEffectiveRangeNotRequired an absent attribute traps.
        joined.enumerateAttribute(key, in: NSMakeRange(0, joined.length), options: .longestEffectiveRangeNotRequired) { value, _, _ in
            note(value)
        }
    }
}

let collector = Collector()
collector.run()
expect(collector.ranges == [NSMakeRange(0, 2), NSMakeRange(2, 2)], "enumerateAttributes ranges")
expect(collector.values == ["-", "x"], "enumerateAttribute values")
print("PASS: NSAttributedString initializers and enumeration blocks")
