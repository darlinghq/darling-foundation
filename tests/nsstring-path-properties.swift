import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// As on macOS, the NSString path accessors import as non-optional properties.
let path = "/tmp/darling/report.tar.gz" as NSString
let last: String = path.lastPathComponent
let directory: String = path.deletingLastPathComponent
let components: [String] = path.pathComponents
let absolute: Bool = path.isAbsolutePath
let representation: UnsafePointer<CChar> = path.fileSystemRepresentation
let appended: String? = path.appendingPathExtension("bak")
expect(last == "report.tar.gz", "lastPathComponent")
expect(directory == "/tmp/darling", "deletingLastPathComponent")
expect(path.pathExtension == "gz", "pathExtension")
expect(path.deletingPathExtension == "/tmp/darling/report.tar", "deletingPathExtension")
expect(components == ["/", "tmp", "darling", "report.tar.gz"], "pathComponents")
expect(absolute, "isAbsolutePath")
expect(String(cString: representation) == "/tmp/darling/report.tar.gz", "fileSystemRepresentation")
expect(appended == "/tmp/darling/report.tar.gz.bak", "appendingPathExtension")
expect(("/a/./b/../c" as NSString).standardizingPath == "/a/c", "standardizingPath")
print("PASS: NSString path properties")
