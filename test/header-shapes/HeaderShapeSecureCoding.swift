// swiftc -typecheck against the built Darling SDK; must pass after the header change.
import Foundation

final class LoadingToken: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    override init() { super.init() }
    required init?(coder: NSCoder) { super.init() }
    func encode(with coder: NSCoder) {}
}

let supported: Bool = LoadingToken.supportsSecureCoding
