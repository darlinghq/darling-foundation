import Foundation

// Descriptions and userInfo of the errors of Foundation's file APIs, seen from Swift.
var failures = 0
func expect(_ got: String?, _ want: String?, _ what: String) {
    if got != want { print("FAIL \(what): got \(got ?? "nil"), expected \(want ?? "nil")"); failures += 1 }
}
let missing = "/nonexistent-swift-test/example.txt"

do { _ = try String(contentsOfFile: missing, encoding: .utf8); print("FAIL no error"); failures += 1 }
catch {
    let n = error as NSError
    expect(n.domain, NSCocoaErrorDomain, "String(contentsOfFile:) domain")
    expect(String(n.code), "260", "String(contentsOfFile:) code")
    expect(n.userInfo[NSLocalizedDescriptionKey] as? String, nil, "String(contentsOfFile:) has no NSLocalizedDescription")
    expect(error.localizedDescription, "The file \u{201c}example.txt\u{201d} couldn\u{2019}t be opened because there is no such file.", "String(contentsOfFile:) description")
}
do { _ = try Data(contentsOf: URL(fileURLWithPath: missing)); print("FAIL no error"); failures += 1 }
catch {
    expect((error as NSError).userInfo[NSLocalizedDescriptionKey] as? String, nil, "Data(contentsOf:) has no NSLocalizedDescription")
    expect(error.localizedDescription, "The file \u{201c}example.txt\u{201d} couldn\u{2019}t be opened because there is no such file.", "Data(contentsOf:) description")
}
do { _ = try FileManager.default.contentsOfDirectory(atPath: "/nonexistent-swift-test"); print("FAIL no error"); failures += 1 }
catch {
    expect((error as NSError).domain, NSCocoaErrorDomain, "contentsOfDirectory domain")
    expect(error.localizedDescription, "The folder \u{201c}nonexistent-swift-test\u{201d} doesn\u{2019}t exist.", "contentsOfDirectory description")
}
print(failures == 0 ? "PASS" : "FAIL (\(failures))")
exit(failures == 0 ? 0 : 1)
