import Foundation

// localizedDescription, failure reason and recovery suggestion of Cocoa errors seen from Swift (CocoaError, an NSError
// bridged to Error, POSIXError). Expected strings are the observations of macOS 10.14.4 and 26.7.3 kept in
// mac-probes/cocoa-error-descriptions (the Swift program itself passes on 26.7.3). Build it on a Mac with
//   swiftc -target x86_64-apple-macosx10.15 -o cocoaerror-descriptions-swift cocoaerror-descriptions-swift.swift
// and run it in the guest with DYLD_FORCE_FLAT_NAMESPACE=1 (the guest's libswiftFoundation looks up
// NSCocoaErrorDomain in CoreFoundation, where it is private).
var failures = 0
func expect(_ got: String?, _ want: String?, _ what: String) {
    if got != want { print("FAIL \(what): got \(got ?? "nil"), expected \(want ?? "nil")"); failures += 1 }
}

let unknown = CocoaError(.fileReadUnknown)
expect(unknown.localizedDescription, "The file couldn\u{2019}t be opened.", "CocoaError(.fileReadUnknown)")
expect((unknown as NSError).localizedFailureReason, nil, "reason of fileReadUnknown")

let noFile = CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: "/tmp/some folder/example.txt"])
expect(noFile.localizedDescription, "The file \u{201c}example.txt\u{201d} couldn\u{2019}t be opened because there is no such file.", "CocoaError with path")
expect((noFile as NSError).localizedFailureReason, "The file doesn\u{2019}t exist.", "failure reason")
expect((CocoaError(.fileWriteNoPermission) as NSError).localizedRecoverySuggestion,
       "To view or change permissions, select the item in the Finder and choose File > Get Info.", "recovery suggestion")

let bridged: Error = NSError(domain: NSCocoaErrorDomain, code: 256, userInfo: nil)
expect(bridged.localizedDescription, "The file couldn\u{2019}t be opened.", "NSError(256) as Error")

let posix = POSIXError(.ENOENT)
expect(posix.localizedDescription, "The operation couldn\u{2019}t be completed. No such file or directory", "POSIXError")
expect(NSError(domain: NSCocoaErrorDomain, code: 265, userInfo: nil).localizedDescription,
       "The operation couldn\u{2019}t be completed. (Cocoa error 265.)", "generic Cocoa code")

print(failures == 0 ? "PASS" : "FAIL (\(failures))")
exit(failures == 0 ? 0 : 1)
