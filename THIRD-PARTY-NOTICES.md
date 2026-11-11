# Third-party notices

Darling Foundation is distributed under the GNU Lesser General Public License
(see `LICENSE`). Some files were adapted from other projects, which keep their
own copyright and licence notices in the files themselves.

## GNUstep base

- `src/NSDateIntervalFormatter.m` and `include/Foundation/NSDateIntervalFormatter.h`
  are adapted from the GNUstep base library (Copyright (C) 2019 Free Software
  Foundation, Inc.), licensed under the GNU Lesser General Public License,
  version 2 or (at your option) any later version. The adaptations replace
  GNUstep's retain/release macros with plain Objective-C message sends and
  declare the accessors as properties.

## Swift project (Apache License 2.0 with Runtime Library Exception)

The text of the Apache License, version 2.0, is in `LICENSES/Apache-2.0.txt`.
The Runtime Library Exception applies to the files below; see
https://swift.org/LICENSE.txt. The notices in the files themselves are kept.

- `src/NSLengthFormatter.m`, `src/NSMassFormatter.m`, `src/NSEnergyFormatter.m`,
  `src/NSUnitFormatterInternal.h` and `src/NSProgress.m` are Objective-C
  ports of Sources/Foundation/{Length,Mass,Energy}Formatter.swift and
  Progress.swift/ProgressFraction.swift from swift-corelibs-foundation
  (Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors).
- `src/NSDecimal.m` is a C port of Decimal+Math.swift and Decimal.swift from
  swift-foundation, tag swift-6.3.3-RELEASE (Copyright (c) 2020 - 2023
  Apple Inc. and the Swift project authors).
