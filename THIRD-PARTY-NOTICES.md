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
