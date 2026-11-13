import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

let plist: NSDictionary = ["name": "Ada", "values": [1, 2, 3]]
var format = PropertyListSerialization.PropertyListFormat.openStep
let binary = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
let decoded = try PropertyListSerialization.propertyList(from: binary, options: [.mutableContainers], format: &format)
expect(format == .binary, "propertyList(from:options:format:) reports .binary")
expect((decoded as? NSDictionary) == plist, "binary round trip")
expect(decoded is NSMutableDictionary, "ReadOptions.mutableContainers yields mutable containers")

let xml = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
_ = try PropertyListSerialization.propertyList(from: xml, options: [], format: &format)
expect(format == .xml, "propertyList(from:options:format:) reports .xml")
expect(PropertyListSerialization.propertyList(plist, isValidFor: .xml), "propertyList(_:isValidFor:)")

let options: String.CompareOptions = [.caseInsensitive, .numeric]
expect(options.rawValue == 65, "CompareOptions raw values")
expect(("File10" as NSString).compare("file9", options: options).rawValue == 1, "compare(_:options:) with [.caseInsensitive, .numeric]")
expect(("Color" as NSString).range(of: "color", options: .caseInsensitive).location == 0, "range(of:options: .caseInsensitive)")
print("PASS: \(binary.count)-byte binary plist, \(xml.count)-byte XML plist")
