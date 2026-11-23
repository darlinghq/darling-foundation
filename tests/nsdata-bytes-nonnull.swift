import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// As on macOS, NSData.bytes imports as a non-optional pointer, so plain pointer arithmetic works.
let data = Data([0x10, 0x20, 0x30]) as NSData
let start = data.bytes
let end = start + 3
expect(end - start == 3, "pointer arithmetic on bytes")
expect(start.load(fromByteOffset: 2, as: UInt8.self) == 0x30, "bytes contents")
print("PASS: NSData.bytes is non-optional")
