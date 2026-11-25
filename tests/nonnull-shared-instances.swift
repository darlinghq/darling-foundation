import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

// As on macOS, the shared instances import as non-optional, so a plain `let` binds the class type.
let manager = FileManager.default
let defaults = UserDefaults.standard
expect(manager.fileExists(atPath: "/"), "FileManager.default")
expect(manager === FileManager.default, "FileManager.default is shared")
expect(defaults.value(forKey: "DarlingNonnullSharedInstancesTestUnsetKey") == nil, "UserDefaults.standard")
expect(defaults === UserDefaults.standard, "UserDefaults.standard is shared")
print("PASS: FileManager.default and UserDefaults.standard are non-optional")
