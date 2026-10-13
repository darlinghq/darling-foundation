// swiftc -typecheck against the built Darling SDK.
// NSAttributedString(string:) is still Optional in this SDK, so the base
// string is force-unwrapped. The assertion is that
// NSMutableAttributedString(attributedString:) is non-optional: with a
// failable import `m` is Optional and `m.length` fails to typecheck.
import Foundation

let s = NSAttributedString(string: "x")!
let m = NSMutableAttributedString(attributedString: s)
_ = m.length
