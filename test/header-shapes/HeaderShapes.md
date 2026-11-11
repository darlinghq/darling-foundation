# Foundation header shape tests

The .m files build with the other tests (ENABLE_TESTS) and print
PASS/FAIL. The .swift files are `swiftc -typecheck` snippets against the
built SDK; they are not wired into CMake.

Only the .swift files distinguish baseline from fix; the .m files
guard that the ObjC call syntax keeps compiling (and that ObjC dot
syntax on zero-arg methods already worked before).

- SecureCoding.swift: `LoadingToken: NSSecureCoding` needs
  `supportsSecureCoding` as a class property. Baseline: does not
  conform. The .m also covers `LoadingToken.supportsSecureCoding`.
- KeyedArchiver.swift, AttributedString.swift: the initializers must be
  `nonnull instancetype` so Swift imports them as non-failable. Baseline
  (`id` / unannotated): inferred type is Optional and the member
  accesses fail to typecheck.

The NSNumber accessor-as-property change lives on
fix/foundation-nsnumber-accessor-properties and must land together with
a darling-swift Foundation overlay change dropping the `()` on
`doubleValue()` and siblings.
