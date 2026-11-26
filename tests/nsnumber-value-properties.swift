import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// As on macOS, the NSNumber value accessors import as properties.
let number: NSNumber = NSNumber(value: 2.5)
let double: Double = number.doubleValue
let float: Float = number.floatValue
let int: Int32 = number.intValue
let integer: Int = number.integerValue
let yes: NSNumber = NSNumber(value: true)
let bool: Bool = yes.boolValue
let negative: NSNumber = NSNumber(value: -42)
let string: String = negative.stringValue
expect(double == 2.5, "doubleValue")
expect(float == 2.5, "floatValue")
expect(int == 2 && integer == 2, "intValue/integerValue")
expect(bool, "boolValue")
expect(string == "-42", "stringValue")
print("PASS: NSNumber value properties")
