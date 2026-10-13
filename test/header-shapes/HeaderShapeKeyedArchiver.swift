// swiftc -typecheck against the built Darling SDK.
// Inference only: with a failable/IUO import, `a` is Optional and the
// member accesses below fail to typecheck.
import Foundation

let a = NSKeyedArchiver(requiringSecureCoding: true)
a.encode(1, forKey: "k")
_ = a.encodedData
