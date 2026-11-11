// swiftc -typecheck against the built Darling SDK.
// The assertion is that NSAttributedString(string:),
// NSAttributedString(string:attributes:) and
// NSMutableAttributedString(attributedString:) are non-optional: with a
// failable import `s`, `a` or `m` is Optional and `.length` fails to typecheck.
import Foundation

let s = NSAttributedString(string: "x")
let a = NSAttributedString(string: "x", attributes: nil)
let m = NSMutableAttributedString(attributedString: s)
_ = s.length
_ = a.length
_ = m.length
