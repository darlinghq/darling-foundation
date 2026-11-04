# NSDictionary selectors named by the Swift Foundation overlay

The Swift Foundation overlay (`NSDictionary.swift` in swift-corelibs-foundation's
`Darwin/Foundation-swiftoverlay`, and `stdlib/public/Darwin/Foundation` in the
Swift 5.x repository) declares three Objective-C methods under `@objc(...)`
names. Swift code compiled against that overlay sends them through
`objc_msgSend`:

| Selector | Swift declaration |
|---|---|
| `-[NSDictionary __swift_objectForKeyedSubscript:]` | `subscript(key: Any) -> Any?` getter |
| `-[NSMutableDictionary __swift_setObject:forKeyedSubscript:]` | the same subscript's setter; `nil` removes the key |
| `-[NSDictionary __swiftInitWithDictionary_NSDictionary:]` | `convenience init(dictionary:)` |

Build `nsdictionary-swift-overlay-selectors.m` as an Objective-C executable
(manual reference counting) linked to Foundation and run it with the candidate
framework. Assertions remain enabled with NDEBUG. Expected marker:

`PASS: NSDictionary Swift overlay selectors`
