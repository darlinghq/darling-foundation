# NSURLQueryItem regression

This synthetic guest regression calls the real public factory and initializer,
checks mutable input isolation, nil versus empty values, literal Unicode/percent
characters, copy ownership, equality/hash, and secure keyed archive round trips.
It also checks explicit rejection of invalid strings and unkeyed coding.

Specification: clean-room rung 1, Apple swift-corelibs-foundation commit
`a656bb7b3d3fbf33ff273e37dd4a78c9011bd4fa`,
`Sources/Foundation/NSURLQueryItem.swift`. This establishes immutable values,
retain-self copying, secure keyed coding with `NS.name`/`NS.value`, and equality.
Rung 2: existing `NSURL.h` declares NSSecureCoding/NSCopying conformance.
Rung 3: the Objective-C factory is specified by Apple public documentation:
https://developer.apple.com/documentation/foundation/nsurlqueryitem/queryitemwithname:value:?language=objc
The explicit NSInvalidArgumentException translation for invalid strings or
unkeyed coding is a conservative rung 6 policy, not an observed Apple error value.
The item performs no percent encoding; NSURLComponents owns query serialization.

Run `build.py --headers-root <independent-superproject> --runtime-root
<snapshot>/image/usr/local/libexec/darling --linker <cctools-Darwin-ld>
--build-dir <private-output>` under the shared heavy-build flock. The baseline
executable links only the immutable runtime Foundation. It must exit 1 with an
unrecognized `queryItemWithName:value:` selector on the original empty class.
Add `--candidate` to compile the exact owned implementation section into a renamed
`DARTestURLQueryItem` class and the same test into an executable. It must exit 0.
The candidate build also compiles the entire production `NSURL.m` without renaming.
No installed Foundation is replaced; this is a focused source-behavior proof,
not a combined runtime installation or app-launch claim.

Headers must come from independently populated, pinned Darling dependencies,
including CoreFoundation and its nested swift-corelibs source, libc, objc4,
cctools, pthread, dyld, Security, and CFNetwork. The Darwin linker must support
`-dylib_file`; ld64.lld does not provide the required dependency remapping.
Use a fresh sanitized DPREFIX, bootstrap `darling shell true`, then run the
executable through `/Volumes/SystemRoot/<private-output>/query-item`.
No messages, credentials, account registration or network service are involved.
