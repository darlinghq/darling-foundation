# NSString normalization forms

Build `normalization.m` as an Objective-C executable linked to Foundation.
The test checks exact UTF-16 code units, not string equality that might treat
canonically equivalent representations as equal. It covers acute-accent
composition/decomposition, preservation of the fi ligature under canonical
composition, compatibility expansion, unchanged inputs and empty strings.
Assertions stay enabled with NDEBUG.

Expected marker: `PASS: exact canonical and compatibility normalization code units`.

Apple specifies [Form C for canonical precomposition](https://developer.apple.com/documentation/foundation/nsstring/precomposedstringwithcanonicalmapping)
and [Form KD for compatibility decomposition](https://developer.apple.com/documentation/foundation/nsstring/decomposedstringwithcompatibilitymapping).
