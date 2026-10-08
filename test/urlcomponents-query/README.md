# Public URL query regression

Specification: clean-room rung 1, Apple swift-corelibs-foundation commit
 a656bb7b3d3fbf33ff273e37dd4a78c9011bd4fa,
Sources/Foundation/NSURLComponents.swift and CoreFoundation/URL.subproj.
The queryItems comments specify duplicate ordering, decoding, missing versus
empty values, and absent versus empty queries. Public documentation:
https://developer.apple.com/documentation/foundation/nsurlcomponents/queryitems

The wrapper delegates parsing/encoding to the real CFURLComponents backend.
This bounded change implements default/string/URL constructors, the previously
declared scheme/host/URL accessors and queryItems getter/setter. It does not
implement the rest of NSURLComponents (including copy/equality, other component
properties or encoded properties), private IMCore APIs or Messages startup.
It depends on the CF backend integration and the peer NSURLQueryItem commit
0343872388937b4f4abdbb6e97810c1e8db93208. Keep those dependency commits separate.

Run build.py with --source-root (independent Darling dependency checkout),
--foundation-root, --query-item-root (independent committed peer checkout),
--runtime-root (immutable libexec/darling image), --build-dir and --linker.
Every compile/link must run under flock /tmp/agent-locks/darling-heavy-build.lock.
The helper compiles the original-name owned translation unit as well as a
renamed candidate and records commands/dependencies. No runtime is replaced.

Bootstrap a fresh private DPREFIX with the immutable non-setuid launcher and
shell true, replace host-home symlinks with empty directories, then run:

- query-regression without arguments: baseline Foundation, expected exit 1
  with absent factory selector.
- backend-regression: direct calls through the normally linked authored
  DARQueryBackend.dylib, expected PASS/exit 0.
- query-regression with the guest path to DARQueryCandidate.dylib: renamed
  authored classes, expected PASS/exit 0. The peer QueryItem section/header
  are copied verbatim into scratch build input and renamed only by a macro.

Renamed candidate execution proves semantics, not canonical Foundation runtime
integration. The parent must perform one combined private Foundation/CF build
and run the normal-class regression there. No preload, Apple hooks, injection,
shared installation, networking, user history or account access is used.
